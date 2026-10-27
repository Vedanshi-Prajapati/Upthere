import Foundation
import CoreLocation
import Observation

@Observable
@MainActor
final class HomeViewModel {
    enum BannerType: Equatable {
        case cached(lastUpdated: String)
        case offline(lastUpdated: String)
        case refreshFailed(reason: String)
        case locationFallback(message: String, action: LocationBannerAction? = nil)
    }

    enum ViewState: Equatable {
        case idle
        case loading(isSilent: Bool)
        case loaded(weather: Weather, banner: BannerType?)
        case error(message: String, isRetryable: Bool)
    }

    private(set) var state: ViewState = .idle
    private(set) var selectedLocation: SavedLocation?
    private(set) var isRefreshing: Bool = false
    private(set) var currentLoadedWeather: Weather?
    private(set) var activeTask: Task<Void, Never>?
    var isCurrentLocation: Bool {
        selectedLocation == nil || selectedLocation?.isCurrentLocation == true
    }

    let locationService: LocationService
    private let getWeatherUseCase: any GetWeatherUseCaseProtocol
    private let cacheManager: WeatherCacheManager
    let locationsManager: SavedLocationsManager
    private let refreshCoordinator: (any WeatherRefreshCoordinating)?
    private let defaults: UserDefaults
    private let openSettingsAction: (() -> Void)?
    private var locationTask: Task<Void, Never>?
    private var latestRequestId = UUID()

    init(
        getWeatherUseCase: any GetWeatherUseCaseProtocol,
        refreshCoordinator: (any WeatherRefreshCoordinating)? = nil,
        cacheManager: WeatherCacheManager? = nil,
        locationsManager: SavedLocationsManager? = nil,
        locationService: LocationService? = nil,
        notificationScheduler: (any NotificationScheduling)? = nil,
        defaults: UserDefaults = AppGroup.defaults,
        openSettingsAction: (() -> Void)? = nil
    ) {
        self.getWeatherUseCase = getWeatherUseCase
        self.cacheManager = cacheManager ?? WeatherCacheManager(defaults: defaults)
        let locManager = locationsManager ?? SavedLocationsManager(defaults: defaults)
        self.locationsManager = locManager
        self.selectedLocation = locManager.selectedLocation
        let locService = locationService ?? LocationService()
        self.locationService = locService
        self.defaults = defaults
        self.openSettingsAction = openSettingsAction

        if let refreshCoordinator {
            self.refreshCoordinator = refreshCoordinator
        } else if let notificationScheduler {
            self.refreshCoordinator = WeatherRefreshCoordinator(
                widgetSnapshotWriter: NoOpWidgetSnapshotWriter(),
                spotlightIndexer: NoOpSpotlightIndexer(),
                rainActivityUpdater: NoOpRainActivityUpdater(),
                notificationScheduler: notificationScheduler,
                fetchMetrics: NoOpFetchMetrics(),
                defaults: defaults
            )
        } else {
            self.refreshCoordinator = nil
        }

        // Consume AsyncStream of location updates
        self.locationTask = Task { [weak self, locService] in
            for await _ in locService.locationUpdates {
                guard let self = self else { break }
                if self.selectedLocation == nil {
                    if self.activeTask != nil || self.isRefreshing {
                        continue
                    }
                    await self.loadWeather(force: true)
                }
            }
        }

        locService.onCityResolved = { [weak self] newCity in
            self?.updateDisplayedCityName(newCity)
        }
    }

    var displayedWeather: Weather? {
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

    func selectLocation(_ location: SavedLocation?) {
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

    func loadWeather(force: Bool = false) async {
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
        let previousWeather = self.currentLoadedWeather

        do {
            let weather: Weather
            let locationToLoad = targetLocation ?? selectedLocation
            if let selected = locationToLoad, !selected.isCurrentLocation, let lat = selected.latitude, let lon = selected.longitude {
                let clLocation = CLLocation(latitude: lat, longitude: lon)
                let subtitle = selected.regionName.isEmpty ? "Selected city" : selected.regionName
                let fetched = try await getWeatherUseCase.execute(for: clLocation, cityName: selected.cityName, subtitle: subtitle, locationStatus: .savedCity)
                weather = fetched.withStatus(.savedCity)
            } else {
                let userLoc: CLLocation?
                if locationService.isAuthorized {
                    do {
                        userLoc = try await locationService.requestCurrentLocation(force: force)
                    } catch {
                        userLoc = nil
                    }
                } else {
                    userLoc = nil
                }

                if let loc = userLoc {
                    let fallbackCity = locationService.matchSavedOrPresetCity(for: loc, savedLocations: locationsManager.locations) ?? "Current Location"
                    let initialSubtitle = locationService.isReducedAccuracy ? "Approximate location" : "Current location"

                    let fetched = try await getWeatherUseCase.execute(for: loc, cityName: fallbackCity, subtitle: initialSubtitle, locationStatus: .live)
                    weather = fetched.withStatus(.live)
                } else {
                    weather = try await getWeatherUseCase.execute()
                }
            }

            guard !Task.isCancelled, self.latestRequestId == requestId else {
                return
            }

            var banner: BannerType? = nil
            if weather.isCached {
                let timeStr = formatTime(weather.fetchTimestamp)
                banner = .cached(lastUpdated: timeStr)
            } else if let copy = weather.locationStatus.bannerCopy {
                banner = .locationFallback(message: copy, action: weather.locationStatus.bannerAction)
            }

            self.currentLoadedWeather = weather
            self.isRefreshing = false
            self.state = .loaded(weather: weather, banner: banner)

            if let coordinator = self.refreshCoordinator {
                await coordinator.handleSuccessfulRefresh(weather)
            }
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

    func refreshWeather() async {
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

    func updateDisplayedCityName(_ newCity: String, subtitle: String? = nil) {
        guard isCurrentLocation else { return }
        guard let current = self.currentLoadedWeather else { return }
        guard current.cityName != newCity, !newCity.isEmpty else { return }
        let updated = current.withCityName(newCity, subtitle: subtitle)
        self.currentLoadedWeather = updated
        if case .loaded(_, let banner) = self.state {
            self.state = .loaded(weather: updated, banner: banner)
        }
    }

    func retryLocation() async {
        await loadWeather(force: true)
    }

    func openSettings() {
        openSettingsAction?()
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
