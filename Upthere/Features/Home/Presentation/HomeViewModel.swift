import Foundation
import CoreLocation
import Observation

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

    private let getWeatherUseCase: any GetWeatherUseCaseProtocol
    private let cacheManager: WeatherCacheManager
    private let locationsManager: SavedLocationsManager
    private var activeTask: Task<Void, Never>?
    private var latestRequestId = UUID()

    public init(
        getWeatherUseCase: any GetWeatherUseCaseProtocol,
        cacheManager: WeatherCacheManager? = nil,
        locationsManager: SavedLocationsManager? = nil
    ) {
        self.getWeatherUseCase = getWeatherUseCase
        self.cacheManager = cacheManager ?? .shared
        let locManager = locationsManager ?? .shared
        self.locationsManager = locManager
        self.selectedLocation = locManager.selectedLocation

        // Listen for live GPS changes if on device location
        LocationService.shared.onLocationChanged = { [weak self] _ in
            guard let self = self else { return }
            if self.selectedLocation == nil {
                Task { @MainActor in
                    await self.loadWeather(force: true)
                }
            }
        }
    }

    public private(set) var currentLoadedWeather: Weather?

    public var displayedWeather: Weather? {
        switch state {
        case .loaded(let weather, _):
            return weather
        case .loading(let isSilent):
            return isSilent ? currentLoadedWeather : nil
        case .idle, .error:
            return nil
        }
    }

    public func selectLocation(_ location: SavedLocation?) {
        locationsManager.selectLocation(location)
        self.selectedLocation = locationsManager.selectedLocation
        self.currentLoadedWeather = nil
        Task {
            await loadWeather(force: true)
        }
    }

    public func loadWeather(force: Bool = false) async {
        let isSilent = displayedWeather != nil
        if case .loading = state, !force {
            return
        }

        // Avoid refetching when switching tabs if we already have fresh loaded weather
        if !force, case .loaded(let weather, _) = state {
            let isFresh = Date().timeIntervalSince(weather.fetchTimestamp) < 1800
            if isFresh {
                return
            }
        }

        let previousWeather = displayedWeather

        activeTask?.cancel()
        let requestId = UUID()
        self.latestRequestId = requestId

        state = .loading(isSilent: isSilent)

        do {
            let weather: Weather

            if let selected = selectedLocation, let lat = selected.latitude, let lon = selected.longitude {
                let clLocation = CLLocation(latitude: lat, longitude: lon)
                let subtitle = selected.regionName.isEmpty ? "Selected city" : selected.regionName
                weather = try await getWeatherUseCase.execute(for: clLocation, cityName: selected.cityName, subtitle: subtitle)
            } else {
                weather = try await getWeatherUseCase.execute()
            }

            guard latestRequestId == requestId else { return }

            // Determine banner
            var banner: BannerType? = nil
            if weather.isCached {
                let timeStr = formatTime(weather.fetchTimestamp)
                banner = .cached(lastUpdated: timeStr)
            } else if weather.locationSubtitle.contains("Default location") || weather.locationSubtitle.contains("disabled") {
                banner = .locationFallback(reason: "Location permission disabled")
            }

            self.currentLoadedWeather = weather
            state = .loaded(weather: weather, banner: banner)

            Task.detached(priority: .utility) {
                SpotlightService.shared.indexWeather(weather)
            }
        } catch {
            guard latestRequestId == requestId else { return }

            let errMsg = error.localizedDescription
            let isRetryable = (error as? WeatherServiceError)?.isRetryable ?? true

            // If we have previous weather or valid cache, preserve it!
            if let prev = previousWeather {
                self.currentLoadedWeather = prev
                state = .loaded(weather: prev, banner: .refreshFailed(reason: errMsg))
                return
            }

            let fallbackKey = cacheManager.cacheKey(for: selectedLocation?.cityName ?? LocationService.shared.currentCityName)
            if let cached = cacheManager.load(key: fallbackKey, allowExpired: true) {
                let timeStr = formatTime(cached.savedAt)
                let cachedWeather = cached.weather.asCached(isCached: true)
                self.currentLoadedWeather = cachedWeather
                state = .loaded(weather: cachedWeather, banner: .offline(lastUpdated: timeStr))
                return
            }

            state = .error(message: errMsg, isRetryable: isRetryable)
        }
    }

    public func refreshWeather() async {
        await loadWeather(force: true)
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
