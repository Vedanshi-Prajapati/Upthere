import Foundation
import CoreLocation
import Observation
import WidgetKit
import os

@Observable
@MainActor
public final class HomeViewModel {
    public enum BannerType: Equatable {
        case cached(lastUpdated: String)
        case offline(lastUpdated: String)
        case refreshFailed(reason: String)
        case locationFallback(reason: String)
    }

    public enum ViewState: Equatable {
        case idle
        case loading(isSilent: Bool)
        case loaded(weather: Weather, banner: BannerType?)
        case error(message: String, isRetryable: Bool)
    }

    public private(set) var state: ViewState = .idle
    public private(set) var selectedLocation: SavedLocation?
    public private(set) var isRefreshing: Bool = false
    public private(set) var currentLoadedWeather: Weather?
    public private(set) var activeTask: Task<Void, Never>?
    public var isCurrentLocation: Bool {
        selectedLocation == nil || selectedLocation?.isCurrentLocation == true
    }

    public let locationService: LocationService
    private let getWeatherUseCase: any GetWeatherUseCaseProtocol
    private let cacheManager: WeatherCacheManager
    public let locationsManager: SavedLocationsManager
    private let notificationScheduler: any NotificationSchedulerProtocol
    private let defaults: UserDefaults
    private var locationTask: Task<Void, Never>?
    private var latestRequestId = UUID()

    public init(
        getWeatherUseCase: any GetWeatherUseCaseProtocol,
        cacheManager: WeatherCacheManager? = nil,
        locationsManager: SavedLocationsManager? = nil,
        locationService: LocationService? = nil,
        notificationScheduler: (any NotificationSchedulerProtocol)? = nil,
        defaults: UserDefaults = AppGroup.defaults
    ) {
        self.getWeatherUseCase = getWeatherUseCase
        self.cacheManager = cacheManager ?? .shared
        let locManager = locationsManager ?? SavedLocationsManager()
        self.locationsManager = locManager
        self.selectedLocation = locManager.selectedLocation
        let locService = locationService ?? LocationService()
        self.locationService = locService
        self.notificationScheduler = notificationScheduler ?? NotificationScheduler.shared
        self.defaults = defaults

        // Consume AsyncStream of location updates
        self.locationTask = Task { [weak self, locService] in
            for await _ in locService.locationUpdates {
                guard let self = self else { break }
                if self.selectedLocation == nil {
                    await self.loadWeather(force: true)
                }
            }
        }
    }

    public var displayedWeather: Weather? {
        if let current = currentLoadedWeather {
            return current
        }
        switch state {
        case .loaded(let weather, _):
            return weather
        case .loading, .idle, .error:
            return nil
        }
    }

    public func selectLocation(_ location: SavedLocation?) {
        locationsManager.selectLocation(location)
        self.selectedLocation = locationsManager.selectedLocation
        self.currentLoadedWeather = nil
        activeTask?.cancel()

        let requestId = UUID()
        self.latestRequestId = requestId
        self.isRefreshing = false
        self.state = .loading(isSilent: false)

        let target = locationsManager.selectedLocation
        let task = Task { @MainActor [weak self] () -> Void in
            guard let self = self else { return }
            await self.performLoad(force: true, requestId: requestId, targetLocation: target)
        }
        self.activeTask = task
    }

    public func loadWeather(force: Bool = false) async {
        // Switching tabs or calling when already loaded without force makes zero calls
        if !force, case .loaded = state {
            return
        }

        // Debounce concurrent non-forced loads by waiting for in-flight task
        if !force, case .loading = state {
            await activeTask?.value
            return
        }

        // Cancel previous in-flight task
        activeTask?.cancel()

        let requestId = UUID()
        self.latestRequestId = requestId

        let hasPreviousWeather = (currentLoadedWeather != nil)
        if hasPreviousWeather {
            self.isRefreshing = true
        } else {
            self.isRefreshing = false
            self.state = .loading(isSilent: false)
        }

        let task = Task { @MainActor [weak self] () -> Void in
            guard let self = self else { return }
            await self.performLoad(force: force, requestId: requestId)
        }
        self.activeTask = task

        await task.value
    }

    private func performLoad(force: Bool, requestId: UUID, targetLocation: SavedLocation? = nil) async {
        let signpostID = AppSignposts.shared.weatherSignposter.makeSignpostID()
        let signpostState = AppSignposts.shared.weatherSignposter.beginInterval("WeatherFetch", id: signpostID)
        defer {
            AppSignposts.shared.weatherSignposter.endInterval("WeatherFetch", signpostState)
            AppSignposts.shared.recordWeatherFetch()
        }

        let previousWeather = self.currentLoadedWeather

        do {
            let weather: Weather
            let locationToLoad = targetLocation ?? selectedLocation
            if let selected = locationToLoad, let lat = selected.latitude, let lon = selected.longitude {
                let clLocation = CLLocation(latitude: lat, longitude: lon)
                let subtitle = selected.regionName.isEmpty ? "Selected city" : selected.regionName
                weather = try await getWeatherUseCase.execute(for: clLocation, cityName: selected.cityName, subtitle: subtitle)
            } else {
                weather = try await getWeatherUseCase.execute()
            }

            guard !Task.isCancelled, self.latestRequestId == requestId else {
                return
            }

            var banner: BannerType? = nil
            if weather.isCached {
                let timeStr = formatTime(weather.fetchTimestamp)
                banner = .cached(lastUpdated: timeStr)
            } else if weather.locationSubtitle.contains("Default location") || weather.locationSubtitle.contains("disabled") {
                banner = .locationFallback(reason: "Location permission disabled")
            }

            self.currentLoadedWeather = weather
            self.isRefreshing = false
            self.state = .loaded(weather: weather, banner: banner)

            let snapshot = WidgetSnapshot(from: weather)
            try? WidgetSnapshotStore.shared.save(snapshot)
            WidgetCenter.shared.reloadAllTimelines()

            if AppGroup.defaults.object(forKey: AppGroup.spotlightEnabledKey) as? Bool ?? true {
                Task.detached(priority: .utility) {
                    await SpotlightService.shared.indexWeather(weather)
                }
            }

            Task { @MainActor in
                await RainActivityManager.shared.updateOnForegroundRefresh(
                    hourly: weather.hourlyForecast,
                    city: weather.cityName
                )
            }

            let rainEnabled = defaults.bool(forKey: AppGroup.rainAlertsKey)
            let severeEnabled = defaults.bool(forKey: AppGroup.severeAlertsKey)
            await notificationScheduler.handleWeatherRefresh(
                weather: weather,
                rainAlertsEnabled: rainEnabled,
                severeAlertsEnabled: severeEnabled,
                now: Date()
            )
        } catch {
            guard !Task.isCancelled, self.latestRequestId == requestId else {
                return
            }

            self.isRefreshing = false
            let errMsg = error.localizedDescription
            let isRetryable = (error as? WeatherServiceError)?.isRetryable ?? true

            // Keep previous weather on screen if refresh fails
            if let prev = previousWeather {
                self.currentLoadedWeather = prev
                self.state = .loaded(weather: prev, banner: .refreshFailed(reason: errMsg))
                return
            }

            let fallbackKey = buildCacheKey()
            if let cached = cacheManager.load(key: fallbackKey, allowExpired: true) {
                let timeStr = formatTime(cached.savedAt)
                let cachedWeather = cached.weather.asCached(isCached: true)
                self.currentLoadedWeather = cachedWeather
                self.state = .loaded(weather: cachedWeather, banner: .offline(lastUpdated: timeStr))
                return
            }

            self.state = .error(message: errMsg, isRetryable: isRetryable)
        }
    }

    public func refreshWeather() async {
        await loadWeather(force: true)
    }

    private func buildCacheKey() -> String {
        let cityName: String
        let coordinate: (lat: Double, lon: Double)?
        if let selected = selectedLocation {
            cityName = selected.cityName
            if let lat = selected.latitude, let lon = selected.longitude {
                coordinate = (lat: lat, lon: lon)
            } else {
                coordinate = nil
            }
        } else {
            cityName = locationService.currentCityName
            if let loc = locationService.currentLocation {
                coordinate = (lat: loc.coordinate.latitude, lon: loc.coordinate.longitude)
            } else {
                coordinate = nil
            }
        }
        return cacheManager.cacheKey(for: cityName, coordinate: coordinate)
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
