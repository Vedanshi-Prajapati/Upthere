import Testing
import Foundation
import CoreLocation
import AppIntents
import SwiftUI
import WidgetKit
@testable import Upthere

@Suite("HomeViewModel Tests")
@MainActor
struct HomeViewModelTests {

    // MARK: - 1. First launch with location permission granted
    @Test("First launch with location permission granted loads weather")
    func firstLaunchPermissionGranted() async {
        let (mockDefaults, suiteName) = makeIsolatedDefaults()
        defer { mockDefaults.removePersistentDomain(forName: suiteName) }

        let locManager = SavedLocationsManager(defaults: mockDefaults)
        let repo = MockWeatherRepository()
        let useCase = GetWeatherUseCase(repository: repo)
        let vm = HomeViewModel(getWeatherUseCase: useCase, locationsManager: locManager)

        await vm.loadWeather()

        guard case .loaded(let weather, _) = vm.state else {
            Issue.record("State was not .loaded")
            return
        }
        #expect(!weather.cityName.isEmpty, "Weather loaded successfully for device location")
    }


    // MARK: - 2. First launch with permission denied and Ghaziabad fallback
    @Test("First launch with permission denied falls back to Ghaziabad")
    func firstLaunchPermissionDeniedGhaziabadFallback() async {
        let (mockDefaults, suiteName) = makeIsolatedDefaults()
        defer { mockDefaults.removePersistentDomain(forName: suiteName) }

        let base = MockWeatherRepository.makeGhaziabadWeather()
        let fallbackWeather = Weather(
            cityName: "Ghaziabad",
            locationSubtitle: "Default location · Uttar Pradesh, India",
            temperature: base.temperature,
            condition: base.condition,
            highTemperature: base.highTemperature,
            lowTemperature: base.lowTemperature,
            feelsLike: base.feelsLike,
            weatherSymbolName: base.weatherSymbolName,
            description: base.description,
            humidity: base.humidity,
            dewPoint: base.dewPoint,
            windSpeed: base.windSpeed,
            windDirection: base.windDirection,
            precipitationChance: base.precipitationChance,
            uvIndex: base.uvIndex,
            uvDescription: base.uvDescription,
            visibility: base.visibility,
            visibilityDescription: base.visibilityDescription,
            pressure: base.pressure,
            pressureTrend: base.pressureTrend,
            alert: nil,
            hourlyForecast: base.hourlyForecast,
            dailyForecast: base.dailyForecast,
            rainWindow: base.rainWindow,
            warmingInsight: base.warmingInsight,
            chanceOfRain: base.chanceOfRain,
            sunrise: base.sunrise,
            sunset: base.sunset,
            fetchTimestamp: Date(),
            isCached: false,
            locationStatus: .denied
        )

        let cache = WeatherCacheManager(defaults: mockDefaults)
        let locManager = SavedLocationsManager(defaults: mockDefaults)
        let repo = MockWeatherRepository(mockWeather: fallbackWeather)
        let useCase = GetWeatherUseCase(repository: repo)
        let vm = HomeViewModel(
            getWeatherUseCase: useCase,
            cacheManager: cache,
            locationsManager: locManager,
            defaults: mockDefaults
        )

        await vm.loadWeather(force: true)

        #expect(vm.displayedWeather?.cityName == "Ghaziabad")
        if case .loaded(let weather, let banner) = vm.state {
            #expect(weather.cityName == "Ghaziabad")
            #expect(banner == .locationFallback(message: "Location access is off. Using Ghaziabad. Open Settings", action: .openSettings))
        } else {
            Issue.record("Expected .loaded state with locationFallback banner")
        }
    }


    // MARK: - 3. Permission revoked after previously being granted
    @Test("Permission revoked after previously being granted preserves previous weather with failure banner")
    func permissionRevokedAfterGranted() async {
        let (mockDefaults, suiteName) = makeIsolatedDefaults()
        defer { mockDefaults.removePersistentDomain(forName: suiteName) }

        let cache = WeatherCacheManager(defaults: mockDefaults)
        let locManager = SavedLocationsManager(defaults: mockDefaults)
        let initialWeather = MockWeatherRepository.makeGhaziabadWeather()
        let repo = MockWeatherRepository(mockWeather: initialWeather)
        let useCase = GetWeatherUseCase(repository: repo)
        let vm = HomeViewModel(
            getWeatherUseCase: useCase,
            cacheManager: cache,
            locationsManager: locManager,
            defaults: mockDefaults
        )

        // 1. Initial successful weather fetch
        await vm.loadWeather(force: true)
        #expect(vm.displayedWeather?.cityName == "Ghaziabad")

        // 2. Permission is now revoked, subsequent refresh fails with permissionDenied
        repo.errorToThrow = LocationServiceError.permissionDenied
        await vm.loadWeather(force: true)

        // 3. View model keeps existing weather on screen and transitions banner to refreshFailed
        #expect(vm.displayedWeather?.cityName == "Ghaziabad", "Previously loaded weather must remain visible")
        #expect(vm.isRefreshing == false)
        if case .loaded(let weather, let banner) = vm.state {
            #expect(weather.cityName == "Ghaziabad")
            if case .refreshFailed(let reason) = banner {
                #expect(reason.contains("denied"))
            } else {
                Issue.record("Expected .refreshFailed banner on permission revocation")
            }
        } else {
            Issue.record("Expected state to stay .loaded with previous weather")
        }
    }


    // MARK: - 4. Location services disabled
    @Test("Location services disabled causes view model to enter retryable error state")
    func locationServicesDisabled() async {
        let (mockDefaults, suiteName) = makeIsolatedDefaults()
        defer { mockDefaults.removePersistentDomain(forName: suiteName) }

        let cache = WeatherCacheManager(defaults: mockDefaults)
        let locManager = SavedLocationsManager(defaults: mockDefaults)
        let repo = MockWeatherRepository()
        repo.errorToThrow = LocationServiceError.servicesDisabled
        let useCase = GetWeatherUseCase(repository: repo)
        let vm = HomeViewModel(
            getWeatherUseCase: useCase,
            cacheManager: cache,
            locationsManager: locManager,
            defaults: mockDefaults
        )

        await vm.loadWeather(force: true)

        guard case .error(let message, let isRetryable) = vm.state else {
            Issue.record("Expected view model to enter error state when location services are disabled")
            return
        }
        #expect(!message.isEmpty)
        #expect(isRetryable == true, "Location service errors should be retryable in view model state")
        #expect(vm.displayedWeather == nil)
        #expect(vm.isRefreshing == false)
    }


    // MARK: - 5. Manual city selection survives app restart
    @Test("Manual city selection survives app restart")
    func manualCitySelectionSurvivesRestart() {
        let (mockDefaults, suiteName) = makeIsolatedDefaults()
        defer { mockDefaults.removePersistentDomain(forName: suiteName) }

        let manager1 = SavedLocationsManager(defaults: mockDefaults)
        let customCity = SavedLocation(cityName: "Kyoto", regionName: "Japan", condition: "Clear", isCurrentLocation: false, latitude: 35.0116, longitude: 135.7681)
        manager1.addLocation(customCity)
        manager1.selectLocation(customCity)

        let manager2 = SavedLocationsManager(defaults: mockDefaults)
        let selected = manager2.selectedLocation

        #expect(selected?.cityName == "Kyoto")
        #expect(selected?.latitude == 35.0116)
    }


    // MARK: - 6. Offline launch with cached data
    @Test("Offline launch with cached data loads cached weather")
    func offlineLaunchWithCachedData() async {
        let (mockDefaults, suiteName) = makeIsolatedDefaults()
        defer { mockDefaults.removePersistentDomain(forName: suiteName) }

        let cache = WeatherCacheManager(defaults: mockDefaults)
        let baseWeather = MockWeatherRepository.makeGhaziabadWeather()
        let mockWeather = Weather(
            cityName: "Sydney",
            locationSubtitle: "New South Wales, Australia",
            temperature: 22.0,
            condition: "Sunny",
            highTemperature: 26.0,
            lowTemperature: 16.0,
            feelsLike: 22.0,
            weatherSymbolName: "sun.max.fill",
            description: "Sunny and clear",
            humidity: 50,
            dewPoint: 12,
            windSpeed: 15,
            windDirection: "SE",
            precipitationChance: 0,
            uvIndex: 5,
            uvDescription: "Moderate",
            visibility: 10,
            visibilityDescription: "Good",
            pressure: 1015,
            pressureTrend: "Steady",
            alert: nil,
            hourlyForecast: baseWeather.hourlyForecast,
            dailyForecast: baseWeather.dailyForecast,
            rainWindow: nil,
            warmingInsight: "",
            chanceOfRain: 0,
            sunrise: "6:00 AM",
            sunset: "6:00 PM"
        )
        let currentCity = LocationService.shared.currentCityName
        cache.save(weather: mockWeather, key: cache.cacheKey(for: currentCity))

        let locManager = SavedLocationsManager(defaults: mockDefaults)
        let repo = MockWeatherRepository()
        repo.errorToThrow = WeatherServiceError.offline
        let useCase = GetWeatherUseCase(repository: repo)
        let vm = HomeViewModel(getWeatherUseCase: useCase, cacheManager: cache, locationsManager: locManager)

        await vm.loadWeather(force: true)

        guard case .loaded(let weather, let banner) = vm.state else {
            Issue.record("State was not .loaded with cached data")
            return
        }

        let isOfflineBanner: Bool
        if case .offline = banner { isOfflineBanner = true } else { isOfflineBanner = false }
        #expect(weather.isCached || isOfflineBanner)
    }


    // MARK: - 7. Offline launch without cached data
    @Test("Offline launch without cached data enters retryable error state")
    func offlineLaunchWithoutCachedData() async {
        let (mockDefaults, suiteName) = makeIsolatedDefaults()
        defer { mockDefaults.removePersistentDomain(forName: suiteName) }

        let cache = WeatherCacheManager(defaults: mockDefaults)
        let repo = MockWeatherRepository()
        repo.errorToThrow = WeatherServiceError.offline
        let useCase = GetWeatherUseCase(repository: repo)
        let vm = HomeViewModel(getWeatherUseCase: useCase, cacheManager: cache)

        await vm.loadWeather(force: true)

        guard case .error(let message, let isRetryable) = vm.state else {
            Issue.record("Did not enter error state")
            return
        }
        #expect(!message.isEmpty)
        #expect(isRetryable)
    }


    // MARK: - 8. Weather API timeout
    @Test("Weather API timeout causes view model to enter retryable error state")
    func weatherApiTimeout() async {
        let (mockDefaults, suiteName) = makeIsolatedDefaults()
        defer { mockDefaults.removePersistentDomain(forName: suiteName) }

        let cache = WeatherCacheManager(defaults: mockDefaults)
        let locManager = SavedLocationsManager(defaults: mockDefaults)
        let repo = MockWeatherRepository()
        repo.errorToThrow = WeatherServiceError.timeout
        let useCase = GetWeatherUseCase(repository: repo)
        let vm = HomeViewModel(
            getWeatherUseCase: useCase,
            cacheManager: cache,
            locationsManager: locManager,
            defaults: mockDefaults
        )

        await vm.loadWeather(force: true)

        guard case .error(let message, let isRetryable) = vm.state else {
            Issue.record("Expected view model to enter error state on API timeout")
            return
        }
        #expect(!message.isEmpty)
        #expect(isRetryable == true, "Weather API timeout must be retryable in view model state")
        #expect(vm.displayedWeather == nil)
        #expect(vm.isRefreshing == false)
    }


    // MARK: - 9. API returns an authorization error
    @Test("API authorization error causes view model to enter non-retryable error state")
    func apiAuthorizationError() async {
        let (mockDefaults, suiteName) = makeIsolatedDefaults()
        defer { mockDefaults.removePersistentDomain(forName: suiteName) }

        let cache = WeatherCacheManager(defaults: mockDefaults)
        let locManager = SavedLocationsManager(defaults: mockDefaults)
        let repo = MockWeatherRepository()
        repo.errorToThrow = WeatherServiceError.unauthorized
        let useCase = GetWeatherUseCase(repository: repo)
        let vm = HomeViewModel(
            getWeatherUseCase: useCase,
            cacheManager: cache,
            locationsManager: locManager,
            defaults: mockDefaults
        )

        await vm.loadWeather(force: true)

        guard case .error(let message, let isRetryable) = vm.state else {
            Issue.record("Expected view model to enter error state on authorization error")
            return
        }
        #expect(!message.isEmpty)
        #expect(isRetryable == false, "Weather API authorization error must be non-retryable in view model state")
        #expect(vm.displayedWeather == nil)
        #expect(vm.isRefreshing == false)
    }


    // MARK: - 12. Old API response arrives after a newer response
    @Test("Old API response arrives after newer response preserves active state")
    func oldApiResponseArrivesAfterNewer() async {
        let repo = MockWeatherRepository()
        let useCase = GetWeatherUseCase(repository: repo)
        let vm = HomeViewModel(getWeatherUseCase: useCase)

        let task1 = Task { await vm.loadWeather(force: true) }
        let task2 = Task { await vm.loadWeather(force: true) }
        _ = await (task1.value, task2.value)

        #expect(vm.state != .idle)
    }


    // MARK: - 13. User changes city during a request
    @Test("User changes city during a request selects the newest city")
    func userChangesCityDuringRequest() async {
        let (mockDefaults, suiteName) = makeIsolatedDefaults()
        defer { mockDefaults.removePersistentDomain(forName: suiteName) }

        let locManager = SavedLocationsManager(defaults: mockDefaults)
        let repo = MockWeatherRepository()
        let useCase = GetWeatherUseCase(repository: repo)
        let vm = HomeViewModel(getWeatherUseCase: useCase, locationsManager: locManager)

        let cityA = SavedLocation(cityName: "Tokyo", regionName: "Japan", condition: "Rain", isCurrentLocation: false, latitude: 35.6762, longitude: 139.6503)
        let cityB = SavedLocation(cityName: "Paris", regionName: "France", condition: "Clear", isCurrentLocation: false, latitude: 48.8566, longitude: 2.3522)

        locManager.addLocation(cityA)
        locManager.addLocation(cityB)

        vm.selectLocation(cityA)
        vm.selectLocation(cityB)

        let deadline = Date().addingTimeInterval(1.0)
        while vm.selectedLocation?.cityName != "Paris" && Date() < deadline {
            try? await Task.sleep(nanoseconds: 1_000_000)
        }

        #expect(vm.selectedLocation?.cityName == "Paris")
    }


    // MARK: - 19. Refresh failure preserves previously valid data
    @Test("Refresh failure preserves valid weather and shows banner")
    func refreshFailurePreservesValidData() async {
        let repo = MockWeatherRepository()
        let useCase = GetWeatherUseCase(repository: repo)
        let vm = HomeViewModel(getWeatherUseCase: useCase)

        await vm.loadWeather()
        guard case .loaded(let initialWeather, _) = vm.state else {
            Issue.record("Initial load failed")
            return
        }

        repo.errorToThrow = WeatherServiceError.offline
        await vm.refreshWeather()

        guard case .loaded(let weatherAfterFailure, let banner) = vm.state else {
            Issue.record("Did not preserve state")
            return
        }
        #expect(weatherAfterFailure.cityName == initialWeather.cityName)
        guard case .refreshFailed = banner else {
            Issue.record("Expected refreshFailed banner")
            return
        }
    }


    // MARK: - 23 (EdgeCaseTests 23). Rapid refreshes do not cause duplicate requests
    @Test("Rapid refreshes are debounced")
    func rapidRefreshesDebounced() async {
        let repo = MockWeatherRepository()
        let useCase = GetWeatherUseCase(repository: repo)
        let vm = HomeViewModel(getWeatherUseCase: useCase)

        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<10 {
                group.addTask {
                    await vm.loadWeather(force: false)
                }
            }
        }

        #expect(repo.fetchCallCount <= 2)
    }


    // MARK: - Fresh data tab switch cache
    @Test("Tab switch avoids refetching when weather data is fresh")
    func tabSwitchAvoidsRefetchingWhenFresh() async {
        let repo = MockWeatherRepository()
        let useCase = GetWeatherUseCase(repository: repo)
        let vm = HomeViewModel(getWeatherUseCase: useCase)

        await vm.loadWeather()
        let countAfterFirstLoad = repo.fetchCallCount
        #expect(countAfterFirstLoad >= 1)

        await vm.loadWeather(force: false)
        #expect(repo.fetchCallCount == countAfterFirstLoad, "Subsequent visit to Home must not refetch fresh data")
    }


    // MARK: - Pull-to-refresh preservation
    @Test("Pull-to-refresh preserves displayed weather")
    func pullToRefreshPreservesDisplayedWeather() async {
        let repo = MockWeatherRepository()
        let useCase = GetWeatherUseCase(repository: repo)
        let vm = HomeViewModel(getWeatherUseCase: useCase)

        await vm.loadWeather()
        #expect(vm.displayedWeather != nil)

        let refreshTask = Task {
            await vm.refreshWeather()
        }
        #expect(vm.displayedWeather != nil)
        await refreshTask.value
        #expect(vm.displayedWeather != nil)
    }


    @Test("Tab switches cause zero repository fetches with counting mock")
    func tabSwitchesCauseZeroFetches() async {
        let repo = MockWeatherRepository()
        let useCase = GetWeatherUseCase(repository: repo)
        let vm = HomeViewModel(getWeatherUseCase: useCase)

        // First appearance load
        await vm.loadWeather()
        #expect(repo.fetchCallCount == 1, "Initial load must call repository once")

        // Simulate switching between Forecast, Insights, Locations, and back to Home
        await vm.loadWeather(force: false)
        await vm.loadWeather(force: false)
        await vm.loadWeather(force: false)
        await vm.loadWeather(force: false)

        #expect(repo.fetchCallCount == 1, "Switching tabs must make zero additional repository fetches")
    }


    @Test("A stale response is dropped when a newer request starts")
    func staleResponseIsDropped() async throws {
        let (mockDefaults, suiteName) = makeIsolatedDefaults()
        defer { mockDefaults.removePersistentDomain(forName: suiteName) }

        let locManager = SavedLocationsManager(defaults: mockDefaults)
        let repo = MockWeatherRepository()
        let useCase = GetWeatherUseCase(repository: repo)
        let vm = HomeViewModel(getWeatherUseCase: useCase, locationsManager: locManager)

        // Set slow response on repository
        repo.delayNanoseconds = 30_000_000 // 30ms

        let cityA = SavedLocation(cityName: "CityA", regionName: "RegionA", condition: "Cloudy", isCurrentLocation: false, latitude: 10, longitude: 20)
        let cityB = SavedLocation(cityName: "CityB", regionName: "RegionB", condition: "Sunny", isCurrentLocation: false, latitude: 30, longitude: 40)
        locManager.addLocation(cityA)
        locManager.addLocation(cityB)

        // Start request A
        vm.selectLocation(cityA)
        try? await Task.sleep(nanoseconds: 5_000_000)

        // Immediately start request B with no delay
        repo.delayNanoseconds = 0
        vm.selectLocation(cityB)

        // Wait for both fetches to complete instead of an arbitrary 400ms sleep
        let deadline = Date().addingTimeInterval(1.0)
        while repo.fetchCallCount < 2 && Date() < deadline {
            try? await Task.sleep(nanoseconds: 2_000_000)
        }
        await Task.yield()

        #expect(vm.displayedWeather?.cityName == "CityB", "Stale response from request A must be dropped and CityB preserved")
    }


    @Test("A refresh failure keeps the old data on screen and clears isRefreshing")
    func refreshFailureKeepsOldData() async {
        let repo = MockWeatherRepository()
        let useCase = GetWeatherUseCase(repository: repo)
        let vm = HomeViewModel(getWeatherUseCase: useCase)

        await vm.loadWeather()
        guard let initialWeather = vm.displayedWeather else {
            Issue.record("Initial weather load failed")
            return
        }
        #expect(!vm.isRefreshing)

        // Subsequent refresh fails
        repo.errorToThrow = WeatherServiceError.offline
        await vm.refreshWeather()

        #expect(!vm.isRefreshing, "isRefreshing flag must reset to false after failure")
        #expect(vm.displayedWeather?.cityName == initialWeather.cityName, "Previous weather must stay on screen")
        if case .loaded(_, let banner) = vm.state {
            #expect(banner == .refreshFailed(reason: WeatherServiceError.offline.localizedDescription))
        } else {
            Issue.record("State should be .loaded with refreshFailed banner")
        }
    }


    @Test("HomeViewModel distinguishes current location vs selected city")
    func homeViewModelCurrentLocationFlag() {
        let (mockDefaults, suiteName) = makeIsolatedDefaults()
        defer { mockDefaults.removePersistentDomain(forName: suiteName) }

        let locManager = SavedLocationsManager(defaults: mockDefaults)
        let repo = MockWeatherRepository()
        let useCase = GetWeatherUseCase(repository: repo)
        let vm = HomeViewModel(getWeatherUseCase: useCase, locationsManager: locManager)

        #expect(vm.isCurrentLocation, "Default selection without selectedLocation is current location")

        let city = SavedLocation(cityName: "Paris", regionName: "France", condition: "Sunny", isCurrentLocation: false, latitude: 48.8566, longitude: 2.3522)
        locManager.addLocation(city)
        vm.selectLocation(city)
        #expect(!vm.isCurrentLocation, "Selected pinned city is not current location")

        vm.selectLocation(nil)
        #expect(vm.isCurrentLocation, "Nil selected location returns to current location")
    }


    @Test("Reverse geocoder that never returns allows weather to load with Current Location")
    func fakeGeocoderNeverReturnsLoadsCurrentLocation() async {
        let (mockDefaults, suiteName) = makeIsolatedDefaults()
        defer { mockDefaults.removePersistentDomain(forName: suiteName) }

        final class FakeHangingGeocoder: GeocoderProtocol, Sendable {
            func reverseGeocode(location: CLLocation) async throws -> String? {
                try? await Task.sleep(nanoseconds: 100_000_000_000)
                return nil
            }
        }

        let fakeManager = FakeLocationManager()
        let fakeGeocoder = FakeHangingGeocoder()
        let sleeper = ManualSleeper()

        let locationService = LocationService(
            manager: fakeManager,
            isLocationServicesEnabledProvider: { true },
            timeoutSleep: { try await sleeper.sleep($0) },
            geocodeTimeout: .seconds(5),
            geocoder: fakeGeocoder
        )

        // Coordinates that do not match any preset city or fallback coordinate
        let testLocation = CLLocation(latitude: 10.1234, longitude: 20.5678)
        fakeManager.onRequestLocation = { [weak locationService] in
            let dummy = CLLocationManager()
            locationService?.locationManager(dummy, didUpdateLocations: [testLocation])
        }

        let locManager = SavedLocationsManager(defaults: mockDefaults)
        let repo = MockWeatherRepository()
        let useCase = GetWeatherUseCase(repository: repo)
        let vm = HomeViewModel(
            getWeatherUseCase: useCase,
            locationsManager: locManager,
            locationService: locationService,
            defaults: mockDefaults
        )

        await vm.loadWeather(force: true)

        guard case .loaded(let weather, _) = vm.state else {
            Issue.record("Expected state to be .loaded, but was \(vm.state)")
            return
        }
        #expect(weather.cityName == "Current Location")
        #expect(vm.displayedWeather?.cityName == "Current Location")
    }


    @Test("When reverse geocoding succeeds later, displayed name updates without refetching weather")
    func geocodeSucceedingLaterUpdatesDisplayedNameWithoutRefetching() async {
        let (mockDefaults, suiteName) = makeIsolatedDefaults()
        defer { mockDefaults.removePersistentDomain(forName: suiteName) }

        /// Lock-protected geocoder holding pending continuations for simulated async delays.
        /// Invariant: Access to pending continuations array is synchronized via `lock`.
        nonisolated final class DelayedGeocoder: GeocoderProtocol, @unchecked Sendable {
            private let lock = NSLock()
            private var continuations: [CheckedContinuation<String?, Never>] = []

            func reverseGeocode(location: CLLocation) async throws -> String? {
                await withCheckedContinuation { cont in
                    self.lock.withLock {
                        self.continuations.append(cont)
                    }
                }
            }

            func resolve(with city: String) {
                let pending = lock.withLock { () -> [CheckedContinuation<String?, Never>] in
                    let c = continuations
                    continuations.removeAll()
                    return c
                }
                for cont in pending {
                    cont.resume(returning: city)
                }
            }

            deinit {
                let pending = lock.withLock { () -> [CheckedContinuation<String?, Never>] in
                    let c = continuations
                    continuations.removeAll()
                    return c
                }
                for cont in pending {
                    cont.resume(returning: nil)
                }
            }
        }

        let delayedGeocoder = DelayedGeocoder()
        let fakeManager = FakeLocationManager()

        let locationService = LocationService(
            manager: fakeManager,
            isLocationServicesEnabledProvider: { true },
            geocodeTimeout: .seconds(5),
            geocoder: delayedGeocoder
        )

        let testLocation = CLLocation(latitude: 10.1234, longitude: 20.5678)
        fakeManager.onRequestLocation = { [weak locationService] in
            let dummy = CLLocationManager()
            locationService?.locationManager(dummy, didUpdateLocations: [testLocation])
        }

        let locManager = SavedLocationsManager(defaults: mockDefaults)
        let repo = MockWeatherRepository()
        let useCase = GetWeatherUseCase(repository: repo)
        let vm = HomeViewModel(
            getWeatherUseCase: useCase,
            locationsManager: locManager,
            locationService: locationService,
            defaults: mockDefaults
        )

        await vm.loadWeather(force: true)

        #expect(vm.displayedWeather?.cityName == "Current Location")
        let fetchCountBefore = repo.fetchCallCount

        // Now resolve geocoder later
        delayedGeocoder.resolve(with: "Honolulu")
        for _ in 0..<50 {
            if vm.displayedWeather?.cityName == "Honolulu" { break }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }

        #expect(vm.displayedWeather?.cityName == "Honolulu")
        #expect(repo.fetchCallCount == fetchCountBefore, "Must not refetch weather when geocoding updates displayed name")
    }

}
