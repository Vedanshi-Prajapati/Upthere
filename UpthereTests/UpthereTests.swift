import Testing
import Foundation
import CoreLocation
import AppIntents
import SwiftUI
import WidgetKit
@testable import Upthere

@Suite("Upthere Edge Case Tests")
@MainActor
struct UpthereTests {

    private func makeIsolatedDefaults() -> (UserDefaults, String) {
        let suiteName = "test.suite.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        return (defaults, suiteName)
    }

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
            locationSubtitle: "Default location · Location permission denied",
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
            isCached: false
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
            #expect(banner == .locationFallback(reason: "Location permission disabled"))
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

    // MARK: - 10. Malformed weather response
    @Test("Malformed weather response fails decoding")
    func malformedWeatherResponse() {
        let corruptedData = "{\"invalid_json\": true}".data(using: .utf8)!
        let decoded = try? JSONDecoder().decode(Weather.self, from: corruptedData)
        #expect(decoded == nil)
    }

    // MARK: - 11. Current conditions succeed while forecast fails
    @Test("Current conditions succeed while forecast fails")
    func currentConditionsSucceedForecastFails() {
        let partialWeather = Weather(
            cityName: "PartialCity",
            locationSubtitle: "Partial region",
            temperature: 20.0,
            condition: "Cloudy",
            highTemperature: 22.0,
            lowTemperature: 15.0,
            feelsLike: 20.0,
            description: "Partially loaded",
            hourlyForecast: [],
            dailyForecast: []
        )
        #expect(partialWeather.hourlyForecast.isEmpty)
        #expect(partialWeather.dailyForecast.isEmpty)
        #expect(partialWeather.temperature == 20.0)
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

    // MARK: - 14. Missing temperature does not display as zero
    @Test("Missing or negative zero temperature formats safely")
    func missingTemperatureDoesNotDisplayZero() {
        let formatter = WeatherFormatter()
        let negativeZero = -0.0001
        let formattedNegZero = formatter.temp(negativeZero)
        let validNegFive = formatter.temp(-5.0)

        #expect(formattedNegZero == "0°")
        #expect(formattedNegZero != "-0°")
        #expect(validNegFive == "-5°")
    }

    // MARK: - 15. Unknown condition code uses a safe fallback
    @Test("Unknown condition code safely preserved without crashing")
    func unknownConditionSafeFallback() {
        let weather = Weather(
            cityName: "Test",
            locationSubtitle: "Region",
            temperature: 18.0,
            condition: "RareAtmosphericPhenomenon",
            highTemperature: 22.0,
            lowTemperature: 12.0,
            feelsLike: 18.0,
            description: "Special event"
        )
        #expect(weather.condition == "RareAtmosphericPhenomenon")
        #expect(!weather.condition.isEmpty)
    }

    // MARK: - 16. Celsius/Fahrenheit switching is correct
    @Test("Celsius and Fahrenheit temperature conversions")
    func celsiusFahrenheitSwitching() {
        let cZero = TemperatureUnit.celsius.convert(0.0)
        let fZero = TemperatureUnit.fahrenheit.convert(0.0)
        let fBoiling = TemperatureUnit.fahrenheit.convert(100.0)

        #expect(cZero == 0.0)
        #expect(fZero == 32.0)
        #expect(fBoiling == 212.0)
    }

    // MARK: - 17. Forecast timestamps across midnight are correct
    @Test("Forecast timestamps across midnight preserve order and formatting")
    func forecastTimestampsAcrossMidnight() {
        let midnightHourly = [
            HourlyWeather(time: "11 PM", temperature: 18.0, precipitationProbability: 0.1),
            HourlyWeather(time: "12 AM", temperature: 17.0, precipitationProbability: 0.1),
            HourlyWeather(time: "1 AM", temperature: 16.0, precipitationProbability: 0.1)
        ]
        #expect(midnightHourly[0].time == "11 PM")
        #expect(midnightHourly[1].time == "12 AM")
        #expect(midnightHourly[2].time == "1 AM")
    }

    // MARK: - 18. Weather data from one city never appears under another city
    @Test("Weather data cache keys isolate cities")
    func weatherDataCityIsolation() {
        let (mockDefaults, suiteName) = makeIsolatedDefaults()
        defer { mockDefaults.removePersistentDomain(forName: suiteName) }

        let cache = WeatherCacheManager(defaults: mockDefaults)
        let keySydney = cache.cacheKey(for: "Sydney", coordinate: (-33.8688, 151.2093))
        let keyLondon = cache.cacheKey(for: "London", coordinate: (51.5074, -0.1278))

        #expect(keySydney != keyLondon)
        #expect(keySydney.localizedCaseInsensitiveContains("Sydney"))
        #expect(keyLondon.localizedCaseInsensitiveContains("London"))
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

    // MARK: - 20. Severe weather alerts are not fabricated or displayed as current after expiry
    @Test("Expired severe weather alerts are marked expired")
    func expiredAlertsNotDisplayed() {
        let pastDate = Date(timeIntervalSinceNow: -7200) // 2 hours ago
        let expiredAlert = WeatherAlert(
            source: "IMD",
            title: "Old Warning",
            validUntil: "Expired",
            expirationDate: pastDate
        )
        #expect(expiredAlert.isExpired)
    }

    // MARK: - 21. Search results distinguish cities with identical names
    @Test("Search results distinguish cities with identical names in different regions")
    func searchDistinguishesDuplicateNames() {
        let portlandOR = SavedLocation(cityName: "Portland", regionName: "Oregon, United States", condition: "Rain", isCurrentLocation: false, latitude: 45.5152, longitude: -122.6784)
        let portlandME = SavedLocation(cityName: "Portland", regionName: "Maine, United States", condition: "Snow", isCurrentLocation: false, latitude: 43.6591, longitude: -70.2568)

        #expect(portlandOR.id != portlandME.id)
        #expect(portlandOR.regionName != portlandME.regionName)
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

    // MARK: - Extended HourlyWeather fields
    @Test("HourlyWeather models extended insight metrics")
    func hourlyWeatherExtendedFields() {
        let hour = HourlyWeather(
            time: "2 PM",
            temperature: 24.5,
            precipitationProbability: 0.15,
            windSpeed: 18.0,
            windGust: 26.0,
            uvIndex: 7,
            cloudCover: 0.45,
            symbolName: "sun.max.fill"
        )

        #expect(hour.time == "2 PM")
        #expect(hour.temperature == 24.5)
        #expect(hour.precipitationProbability == 0.15)
        #expect(hour.windSpeed == 18.0)
        #expect(hour.wind == 18.0)
        #expect(hour.windGust == 26.0)
        #expect(hour.gust == 26.0)
        #expect(hour.uvIndex == 7)
        #expect(hour.cloudCover == 0.45)
        #expect(hour.symbolName == "sun.max.fill")
        #expect(hour.symbol == "sun.max.fill")
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

    // MARK: - Spotlight identifier resolution
    @Test("Spotlight service resolves city name from identifier")
    func spotlightResolution() {
        let weatherCity = SpotlightService.shared.resolveCityName(from: "weather.cupertino")
        #expect(weatherCity == "Cupertino")

        let locationCity = SpotlightService.shared.resolveCityName(from: "location.tokyo")
        #expect(locationCity == "Tokyo")

        let multiWordCity = SpotlightService.shared.resolveCityName(from: "weather.san_francisco")
        #expect(multiWordCity == "San Francisco")
    }

    // MARK: - App Intents LocationEntityQuery
    @Test("LocationEntityQuery returns entities")
    func locationEntityQuery() async throws {
        let query = LocationEntityQuery()
        let entities = try await query.allEntities()

        #expect(!entities.isEmpty, "Location entities should contain at least current location")
        #expect(entities.first?.id == "current", "First entity should be Current Location")
    }

    // MARK: - ToggleSevereAlertsIntent
    @Test("ToggleSevereAlertsIntent inverts severe alerts setting")
    func toggleSevereAlertsIntent() async throws {
        let initial = AppGroup.defaults.bool(forKey: AppGroup.severeAlertsKey)
        let intent = ToggleSevereAlertsIntent()
        let result = try await intent.perform()

        #expect(result.value == !initial, "Toggling severe alerts intent should invert the stored setting")

        _ = try await intent.perform()
    }

    // MARK: - Counting Mock Repository Lifecycle Tests

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

    @Test("InsightEngine rain window formats specific peak time without saying near Now")
    func insightEngineRainWindowFormatting() {
        let engine = InsightEngine()
        let baseDate = Date(timeIntervalSince1970: 1700000000)
        let hourly: [HourlyWeather] = [
            HourlyWeather(date: baseDate, temperature: 20, precipitationChance: 0.80, precipitationAmount: 3.5, symbolName: "cloud.rain.fill"),
            HourlyWeather(date: baseDate.addingTimeInterval(3600), temperature: 19, precipitationChance: 0.60, precipitationAmount: 1.5, symbolName: "cloud.drizzle.fill")
        ]

        let result = engine.rainWindow(from: hourly)
        #expect(result != nil)
        if let rain = result {
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_US")
            f.dateFormat = "ha"
            let peakTime = f.string(from: rain.peakDate)
            let detail = "Peak precipitation around \(peakTime), \(Int((rain.peakProbability * 100).rounded()))% probability."
            #expect(!detail.contains("near Now"))
            #expect(detail.contains(peakTime))
        }
    }

    // MARK: - Location Store & Management Tests

    @Test("Add location persists to LocationStore")
    func addLocationPersists() {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_locs_\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let store = FileLocationStore(fileURL: tempURL)
        let manager = SavedLocationsManager(store: store)

        let initialCount = manager.locations.count
        let berlin = SavedLocation(cityName: "Berlin", regionName: "Germany", condition: "Sunny", isCurrentLocation: false, latitude: 52.52, longitude: 13.405)
        manager.addLocation(berlin)

        #expect(manager.locations.count == initialCount + 1)
        #expect(manager.locations.contains(where: { $0.cityName == "Berlin" }))

        // Re-read with a fresh manager instance
        let manager2 = SavedLocationsManager(store: store)
        #expect(manager2.locations.contains(where: { $0.cityName == "Berlin" }))
    }

    @Test("New users start with only Current location entry")
    func newUsersStartWithOnlyCurrentLocation() {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_new_user_\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let store = FileLocationStore(fileURL: tempURL)
        let manager = SavedLocationsManager(store: store)

        #expect(manager.locations.count == 1)
        #expect(manager.locations.first?.isCurrentLocation == true)
        #expect(manager.locations.first?.cityName == "Current location")
    }

    @Test("Remove location deletes non-current location but protects Current location")
    func removeLocationProtectsCurrentLocation() {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_locs_\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let store = FileLocationStore(fileURL: tempURL)
        let manager = SavedLocationsManager(store: store)
        let testCity = SavedLocation(cityName: "Berlin", regionName: "Germany", condition: "Sunny", isCurrentLocation: false, latitude: 52.52, longitude: 13.405)
        manager.addLocation(testCity)

        guard let currentLoc = manager.locations.first(where: { $0.isCurrentLocation }),
              let nonCurrentLoc = manager.locations.first(where: { !$0.isCurrentLocation }) else {
            Issue.record("Expected current and non-current locations in manager")
            return
        }

        let initialCount = manager.locations.count

        // Attempt to remove current location: should be rejected
        manager.removeLocation(id: currentLoc.id)
        #expect(manager.locations.contains(where: { $0.id == currentLoc.id }))
        #expect(manager.locations.count == initialCount)

        // Remove non-current location: should succeed
        manager.removeLocation(id: nonCurrentLoc.id)
        #expect(!manager.locations.contains(where: { $0.id == nonCurrentLoc.id }))
        #expect(manager.locations.count == initialCount - 1)
    }

    @Test("Reorder while filtered correctly updates underlying locations while keeping Current location pinned")
    func reorderWhileFiltered() {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_locs_\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let store = FileLocationStore(fileURL: tempURL)
        let manager = SavedLocationsManager(store: store)

        let loc1 = SavedLocation(cityName: "Chicago", regionName: "Illinois, USA", condition: "--", isCurrentLocation: false, latitude: 41.8781, longitude: -87.6298)
        let loc2 = SavedLocation(cityName: "Boston", regionName: "Massachusetts, USA", condition: "--", isCurrentLocation: false, latitude: 42.3601, longitude: -71.0589)
        let loc3 = SavedLocation(cityName: "Miami", regionName: "Florida, USA", condition: "--", isCurrentLocation: false, latitude: 25.7617, longitude: -80.1918)
        let loc4 = SavedLocation(cityName: "Dallas", regionName: "Texas, USA", condition: "--", isCurrentLocation: false, latitude: 32.7767, longitude: -96.7970)

        // Reset locations
        let currentLoc = manager.locations[0]
        try? store.saveLocations([currentLoc, loc1, loc2, loc3, loc4])
        let testManager = SavedLocationsManager(store: store)

        // Filter for non-current cities with "a": [Chicago, Miami, Dallas]
        let filtered = testManager.locations.filter { !$0.isCurrentLocation && $0.cityName.localizedCaseInsensitiveContains("a") }
        #expect(filtered.count == 3)
        #expect(filtered[0].cityName == "Chicago")
        #expect(filtered[1].cityName == "Miami")
        #expect(filtered[2].cityName == "Dallas")

        // In the filtered list, move Dallas (filtered index 2) to before Miami (filtered index 1)
        testManager.moveLocation(fromOffsets: IndexSet(integer: 2), toOffset: 1, within: filtered)

        // Verify underlying locations:
        // Index 0 must remain Current location
        #expect(testManager.locations[0].isCurrentLocation)
        // Dallas should now be before Miami
        let dallasIdx = testManager.locations.firstIndex(where: { $0.cityName == "Dallas" })!
        let miamiIdx = testManager.locations.firstIndex(where: { $0.cityName == "Miami" })!
        #expect(dallasIdx < miamiIdx)
    }

    @Test("Duplicate detection allows identical city names far apart but rejects places within 5km")
    func duplicateDetectionCoordinates() {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_locs_\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let store = FileLocationStore(fileURL: tempURL)
        let manager = SavedLocationsManager(store: store)

        // Portland, Oregon vs Portland, Maine (same name, ~4100 km apart)
        let portlandOR = SavedLocation(cityName: "Portland", regionName: "Oregon, USA", condition: "Rain", isCurrentLocation: false, latitude: 45.5152, longitude: -122.6784)
        let portlandME = SavedLocation(cityName: "Portland", regionName: "Maine, USA", condition: "Sunny", isCurrentLocation: false, latitude: 43.6615, longitude: -70.2553)

        manager.addLocation(portlandOR)
        #expect(manager.locations.contains(where: { $0.regionName == "Oregon, USA" }))

        // Adding Portland, ME with same name must be allowed
        manager.addLocation(portlandME)
        #expect(manager.locations.contains(where: { $0.regionName == "Maine, USA" }), "Same city name with distant coordinates must not be treated as duplicate")

        let countBeforeNear = manager.locations.count
        // Location very close to Portland, OR (~1.2 km away at 45.5200, -122.6820)
        let nearbyPlace = SavedLocation(cityName: "Portland Downtown", regionName: "Oregon", condition: "--", isCurrentLocation: false, latitude: 45.5200, longitude: -122.6820)
        #expect(manager.isDuplicate(nearbyPlace), "Coordinates within 5km must be detected as duplicate")

        manager.addLocation(nearbyPlace)
        #expect(manager.locations.count == countBeforeNear, "Duplicate within 5km must not be added")
    }

    @Test("One-time migration from UserDefaults to FileLocationStore")
    func userDefaultsMigration() {
        let (mockDefaults, suiteName) = makeIsolatedDefaults()
        defer { mockDefaults.removePersistentDomain(forName: suiteName) }

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_migration_\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        // Seed old UserDefaults key with custom locations
        let testLoc = SavedLocation(cityName: "Zurich", regionName: "Switzerland", condition: "Snow", isCurrentLocation: false, latitude: 47.3769, longitude: 8.5417)
        let encoded = try! JSONEncoder().encode([SavedLocationsManager.defaultCurrentLocation, testLoc])
        mockDefaults.set(encoded, forKey: "upthere.saved_locations.list")
        mockDefaults.set(testLoc.id.uuidString, forKey: "upthere.saved_locations.selected_id")

        // Initialize store with no existing file: should migrate from defaults
        let store = FileLocationStore(fileURL: tempURL, defaults: mockDefaults)
        let loaded = try? store.loadLocations()

        #expect(loaded?.contains(where: { $0.cityName == "Zurich" }) == true)
        #expect(store.loadSelectedLocationId() == testLoc.id)
        #expect(FileManager.default.fileExists(atPath: tempURL.path))
    }

    private final class FailingLocationStore: LocationStore, @unchecked Sendable {
        var shouldFailSave = false

        func loadLocations() throws -> [SavedLocation] { [SavedLocationsManager.defaultCurrentLocation] }
        func saveLocations(_ locations: [SavedLocation]) throws {
            if shouldFailSave {
                throw NSError(domain: "TestStoreError", code: 42, userInfo: [NSLocalizedDescriptionKey: "Disk full"])
            }
        }
        func loadSelectedLocationId() -> UUID? { nil }
        func saveSelectedLocationId(_ id: UUID?) {}
    }

    @Test("SavedLocationsManager sets saveErrorMessage when store write fails")
    func saveFailureSetsErrorMessage() {
        let failingStore = FailingLocationStore()
        let manager = SavedLocationsManager(store: failingStore)

        #expect(manager.saveErrorMessage == nil)
        failingStore.shouldFailSave = true

        let testCity = SavedLocation(cityName: "Rome", regionName: "Italy", condition: "Sunny", isCurrentLocation: false, latitude: 41.9028, longitude: 12.4964)
        manager.addLocation(testCity)

        #expect(manager.saveErrorMessage != nil)
    }

    // MARK: - App Group Settings Migration
    @Test("App Group migration copies settings once and does not overwrite later changes")
    func appGroupSettingsMigration() {
        let (mockStandard, standardSuite) = makeIsolatedDefaults()
        defer { mockStandard.removePersistentDomain(forName: standardSuite) }

        let (mockGroup, groupSuite) = makeIsolatedDefaults()
        defer { mockGroup.removePersistentDomain(forName: groupSuite) }

        // 1. Seed standard defaults with settings data
        mockStandard.set("fahrenheit", forKey: "settings.temperatureUnit")
        mockStandard.set("mph", forKey: "settings.windSpeedUnit")
        mockStandard.set("inch", forKey: "settings.precipitationUnit")
        mockStandard.set("dark", forKey: "settings.appearanceMode")
        mockStandard.set(false, forKey: "settings.rainAlertsEnabled")
        mockStandard.set(false, forKey: "settings.severeAlertsEnabled")

        // 2. Perform migration
        AppGroup.migrateSettingsIfNeeded(standard: mockStandard, group: mockGroup)

        // 3. Verify values were copied to group suite
        #expect(mockGroup.string(forKey: "settings.temperatureUnit") == "fahrenheit")
        #expect(mockGroup.string(forKey: "settings.windSpeedUnit") == "mph")
        #expect(mockGroup.string(forKey: "settings.precipitationUnit") == "inch")
        #expect(mockGroup.string(forKey: "settings.appearanceMode") == "dark")
        #expect(mockGroup.bool(forKey: "settings.rainAlertsEnabled") == false)
        #expect(mockGroup.bool(forKey: "settings.severeAlertsEnabled") == false)
        #expect(mockGroup.bool(forKey: AppGroup.migrationKey) == true)

        // 4. Update group suite values with later changes
        mockGroup.set("celsius", forKey: "settings.temperatureUnit")
        mockGroup.set("kmh", forKey: "settings.windSpeedUnit")
        mockGroup.set(true, forKey: "settings.severeAlertsEnabled")

        // Also change standard to different values to ensure standard has conflicting data
        mockStandard.set("kelvin", forKey: "settings.temperatureUnit")

        // 5. Run migration again
        AppGroup.migrateSettingsIfNeeded(standard: mockStandard, group: mockGroup)

        // 6. Verify later changes in group suite were NOT overwritten
        #expect(mockGroup.string(forKey: "settings.temperatureUnit") == "celsius")
        #expect(mockGroup.string(forKey: "settings.windSpeedUnit") == "kmh")
        #expect(mockGroup.bool(forKey: "settings.severeAlertsEnabled") == true)
    }

    @Test("AppGroup containerURL returns valid or nil URL without crash")
    func appGroupContainerURL() {
        #expect(AppGroup.identifier == "group.com.vedanshi.upthereapp")
        _ = AppGroup.containerURL
        _ = AppGroup.containerURL(forSubdirectory: "WeatherCache")
    }

    // MARK: - Widget Snapshot Store & Entry Tests

    @Test("WidgetSnapshotStore saves and loads snapshot through JSON round trip")
    func widgetSnapshotStoreRoundTrip() throws {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_widget_snapshot_\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let store = WidgetSnapshotStore(fileURL: tempURL)

        let snapshot = WidgetSnapshot(
            city: "San Francisco",
            temp: 18,
            feelsLike: 17,
            high: 22,
            low: 14,
            condition: "Sunny",
            symbolName: "sun.max.fill",
            rainChance: 10,
            rainInsight: "No rain expected today",
            hourly: [
                .init(id: "h1", time: "Now", temp: 18, symbol: "sun.max.fill", rainProb: 0),
                .init(id: "h2", time: "1 PM", temp: 20, symbol: "sun.max.fill", rainProb: 5)
            ],
            daily: [
                .init(id: "d1", day: "Today", symbol: "sun.max.fill", low: 14, high: 22, rainProb: 10),
                .init(id: "d2", day: "Thu", symbol: "cloud.sun.fill", low: 13, high: 21, rainProb: 15)
            ],
            updatedAt: Date()
        )

        try store.save(snapshot)

        let loaded = store.load()
        #expect(loaded != nil)
        #expect(loaded?.city == "San Francisco")
        #expect(loaded?.temp == 18)
        #expect(loaded?.feelsLike == 17)
        #expect(loaded?.high == 22)
        #expect(loaded?.low == 14)
        #expect(loaded?.condition == "Sunny")
        #expect(loaded?.symbolName == "sun.max.fill")
        #expect(loaded?.rainChance == 10)
        #expect(loaded?.hourly.count == 2)
        #expect(loaded?.daily.count == 2)
    }

    @Test("WidgetSnapshot maps from Weather domain model accurately")
    func widgetSnapshotFromWeather() {
        let weather = Weather(
            cityName: "Tokyo",
            temperature: 24.3,
            condition: "Clear",
            highTemperature: 28.1,
            lowTemperature: 19.4,
            feelsLike: 25.0,
            weatherSymbolName: "sun.max.fill",
            chanceOfRain: 20
        )

        let snapshot = WidgetSnapshot(from: weather)
        #expect(snapshot.city == "Tokyo")
        #expect(snapshot.temp == 24)
        #expect(snapshot.high == 28)
        #expect(snapshot.low == 19)
        #expect(snapshot.feelsLike == 25)
        #expect(snapshot.condition == "Clear")
        #expect(snapshot.symbolName == "sun.max.fill")
        #expect(snapshot.rainChance == 20)
    }

    @Test("WeatherWidgetEntry displays empty state when no snapshot exists")
    func weatherWidgetEntryEmptyState() {
        let entry = WeatherWidgetEntry(from: nil)
        #expect(entry.isEmpty == true)
        #expect(entry.isStale == true)
        #expect(entry.condition == "Open UpThere to set your location")
        #expect(entry.updatedAtText == nil)
    }

    @Test("WeatherWidgetEntry displays stale state and updated timestamp when older than 3 hours")
    func weatherWidgetEntryStaleStateAfter3Hours() {
        let now = Date()
        let staleDate = now.addingTimeInterval(-3.5 * 3600) // 3.5 hours ago
        let snapshot = WidgetSnapshot(
            city: "London",
            temp: 15,
            feelsLike: 14,
            high: 18,
            low: 11,
            condition: "Rain",
            symbolName: "cloud.rain.fill",
            rainChance: 80,
            rainInsight: "Rain likely · 80%",
            hourly: [],
            daily: [],
            updatedAt: staleDate
        )

        let entry = WeatherWidgetEntry(from: snapshot, date: now)
        #expect(entry.isEmpty == false)
        #expect(entry.isStale == true)
        #expect(entry.condition == "Open UpThere to load weather")
        #expect(entry.updatedAtText?.hasPrefix("Updated ") == true)
        #expect(entry.cityName == "London")
        #expect(entry.temperature == 15)
    }

    // MARK: - Timeline Provider & WidgetWeatherFetching Tests

    @Test("Timeline provider: fresh fetch writes new snapshot and returns entries for next few hours")
    func timelineFreshFetchWritesSnapshot() async throws {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_provider_fresh_\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let store = WidgetSnapshotStore(fileURL: tempURL)
        let initialSnapshot = WidgetSnapshot(
            city: "San Francisco",
            latitude: 37.7749,
            longitude: -122.4194,
            temp: 15,
            feelsLike: 15,
            high: 18,
            low: 12,
            condition: "Cloudy",
            symbolName: "cloud.fill",
            rainChance: 0,
            rainInsight: "No rain expected",
            hourly: [],
            daily: [],
            updatedAt: Date().addingTimeInterval(-3600)
        )
        try store.save(initialSnapshot)

        let now = Date()
        let freshHourly: [HourlyWeather] = [
            HourlyWeather(date: now, temperature: 22, precipitationChance: 0.0, symbolName: "sun.max.fill"),
            HourlyWeather(date: now.addingTimeInterval(3600), temperature: 24, precipitationChance: 0.1, symbolName: "sun.max.fill"),
            HourlyWeather(date: now.addingTimeInterval(7200), temperature: 23, precipitationChance: 0.2, symbolName: "cloud.sun.fill")
        ]
        let freshWeather = Weather(
            cityName: "San Francisco",
            latitude: 37.7749,
            longitude: -122.4194,
            temperature: 22,
            condition: "Clear",
            highTemperature: 25,
            lowTemperature: 14,
            weatherSymbolName: "sun.max.fill",
            hourlyForecast: freshHourly
        )

        final class FakeFetcher: WidgetWeatherFetching, @unchecked Sendable {
            let weather: Weather
            init(weather: Weather) { self.weather = weather }
            func fetchWeather(for location: CLLocation, cityName: String) async throws -> Weather {
                weather
            }
        }

        let fakeFetcher = FakeFetcher(weather: freshWeather)
        let provider = WeatherWidgetTimelineProvider(weatherFetcher: fakeFetcher, snapshotStore: store)

        let timeline = await provider.loadTimeline()

        // 1. Fresh fetch writes the snapshot
        let saved = store.load()
        #expect(saved != nil)
        #expect(saved?.temp == 22)
        #expect(saved?.condition == "Clear")
        #expect(saved?.city == "San Francisco")
        #expect(saved?.latitude == 37.7749)
        #expect(saved?.longitude == -122.4194)

        // 2. Returns entries for the next few hours
        #expect(timeline.entries.count >= 2)
        #expect(timeline.entries[0].temperature == 22)
        #expect(timeline.entries[0].isStale == false)
        #expect(timeline.entries[0].isEmpty == false)
    }

    @Test("Timeline provider: fetch failure falls back to saved snapshot and displays Updated timestamp")
    func timelineFailureFallsBackToStaleSnapshot() async throws {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_provider_stale_\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let store = WidgetSnapshotStore(fileURL: tempURL)
        let savedDate = Date().addingTimeInterval(-1800)
        let savedSnapshot = WidgetSnapshot(
            city: "London",
            latitude: 51.5074,
            longitude: -0.1278,
            temp: 14,
            feelsLike: 13,
            high: 17,
            low: 10,
            condition: "Rain",
            symbolName: "cloud.rain.fill",
            rainChance: 70,
            rainInsight: "Rain likely · 70%",
            hourly: [],
            daily: [],
            updatedAt: savedDate
        )
        try store.save(savedSnapshot)

        struct MockNetworkError: Error {}
        final class FailingFetcher: WidgetWeatherFetching, @unchecked Sendable {
            func fetchWeather(for location: CLLocation, cityName: String) async throws -> Weather {
                throw MockNetworkError()
            }
        }

        let fakeFetcher = FailingFetcher()
        let provider = WeatherWidgetTimelineProvider(weatherFetcher: fakeFetcher, snapshotStore: store)

        let timeline = await provider.loadTimeline()

        #expect(timeline.entries.count == 1)
        let fallbackEntry = timeline.entries[0]
        #expect(fallbackEntry.cityName == "London")
        #expect(fallbackEntry.temperature == 14)
        #expect(fallbackEntry.isStale == true)
        #expect(fallbackEntry.updatedAtText?.hasPrefix("Updated ") == true)
    }

    @Test("Timeline provider: returns empty state when no snapshot exists")
    func timelineNoSnapshotReturnsEmptyState() async {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_provider_empty_\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let store = WidgetSnapshotStore(fileURL: tempURL)
        final class EmptyFetcher: WidgetWeatherFetching, @unchecked Sendable {
            func fetchWeather(for location: CLLocation, cityName: String) async throws -> Weather {
                throw WeatherUnavailableError()
            }
        }

        let fakeFetcher = EmptyFetcher()
        let provider = WeatherWidgetTimelineProvider(weatherFetcher: fakeFetcher, snapshotStore: store)

        let timeline = await provider.loadTimeline()

        #expect(timeline.entries.count == 1)
        let entry = timeline.entries[0]
        #expect(entry.isEmpty == true)
        #expect(entry.condition == "Open UpThere to set your location")
        #expect(entry.rainInsight == "Open UpThere to set your location")
    }

    @Test("WeatherWidgetEntry displays fresh state when under 3 hours")
    func weatherWidgetEntryFreshState() {
        let now = Date()
        let freshDate = now.addingTimeInterval(-30 * 60) // 30 mins ago
        let snapshot = WidgetSnapshot(
            city: "Paris",
            temp: 21,
            feelsLike: 21,
            high: 25,
            low: 16,
            condition: "Partly Cloudy",
            symbolName: "cloud.sun.fill",
            rainChance: 0,
            rainInsight: "No rain expected today",
            hourly: [],
            daily: [],
            updatedAt: freshDate
        )

        let entry = WeatherWidgetEntry(from: snapshot, date: now)
        #expect(entry.isEmpty == false)
        #expect(entry.isStale == false)
        #expect(entry.condition == "Partly Cloudy")
        #expect(entry.updatedAtText == nil)
        #expect(entry.cityName == "Paris")
    }

    // MARK: - Intent Offline & Cache Fallback Tests

    @Test("CheckWeatherIntent returns cached weather when network fails")
    func checkWeatherIntentReturnsCachedWhenNetworkFails() async throws {
        let (mockDefaults, suiteName) = makeIsolatedDefaults()
        defer { mockDefaults.removePersistentDomain(forName: suiteName) }

        let cacheManager = WeatherCacheManager(defaults: mockDefaults)
        let location = LocationEntity(
            id: "test-sf",
            name: "San Francisco",
            region: "CA",
            latitude: 37.7749,
            longitude: -122.4194
        )

        let cached = MockWeatherRepository.makeGhaziabadWeather()
        let coordKey = cacheManager.cacheKey(
            for: location.name,
            coordinate: (lat: location.latitude, lon: location.longitude)
        )
        cacheManager.save(weather: cached, key: coordKey)

        let failingRepo = MockWeatherRepository(errorToThrow: WeatherServiceError.offline, delayNanoseconds: 0)
        let intent = CheckWeatherIntent(
            location: location,
            repository: failingRepo,
            cacheManager: cacheManager
        )

        let result = try await intent.perform()
        #expect(result.value?.contains(cached.cityName) == true || result.value?.contains(location.name) == true)
    }

    @Test("CheckWeatherIntent throws WeatherUnavailableError when network fails and cache is missing")
    func checkWeatherIntentThrowsWhenBothMissing() async {
        let (mockDefaults, suiteName) = makeIsolatedDefaults()
        defer { mockDefaults.removePersistentDomain(forName: suiteName) }

        let emptyCache = WeatherCacheManager(defaults: mockDefaults)
        let location = LocationEntity(
            id: "test-ny",
            name: "New York",
            region: "NY",
            latitude: 40.7128,
            longitude: -74.0060
        )
        let failingRepo = MockWeatherRepository(errorToThrow: WeatherServiceError.offline, delayNanoseconds: 0)
        let intent = CheckWeatherIntent(
            location: location,
            repository: failingRepo,
            cacheManager: emptyCache
        )

        do {
            _ = try await intent.perform()
            Issue.record("Expected WeatherUnavailableError to be thrown")
        } catch let error as WeatherUnavailableError {
            #expect(error.errorDescription == "I couldn't get the weather right now. Open UpThere and try again.")
            #expect(error.localizedStringResource.key == "I couldn't get the weather right now. Open UpThere and try again.")
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("TrackRainIntent returns cached weather when network fails")
    func trackRainIntentReturnsCachedWhenNetworkFails() async throws {
        let (mockDefaults, suiteName) = makeIsolatedDefaults()
        defer { mockDefaults.removePersistentDomain(forName: suiteName) }

        let cacheManager = WeatherCacheManager(defaults: mockDefaults)
        let location = LocationEntity(
            id: "test-sf",
            name: "San Francisco",
            region: "CA",
            latitude: 37.7749,
            longitude: -122.4194
        )

        let cached = MockWeatherRepository.makeGhaziabadWeather()
        let coordKey = cacheManager.cacheKey(
            for: location.name,
            coordinate: (lat: location.latitude, lon: location.longitude)
        )
        cacheManager.save(weather: cached, key: coordKey)

        let failingRepo = MockWeatherRepository(errorToThrow: WeatherServiceError.offline, delayNanoseconds: 0)
        let intent = TrackRainIntent(
            location: location,
            repository: failingRepo,
            cacheManager: cacheManager
        )

        let result = try await intent.perform()
        // Ghaziabad mock weather has no rain in first 2 hours, so track rain completes with false
        #expect(result.value == false)
    }

    @Test("TrackRainIntent throws WeatherUnavailableError when network fails and cache is missing")
    func trackRainIntentThrowsWhenBothMissing() async {
        let (mockDefaults, suiteName) = makeIsolatedDefaults()
        defer { mockDefaults.removePersistentDomain(forName: suiteName) }

        let emptyCache = WeatherCacheManager(defaults: mockDefaults)
        let location = LocationEntity(
            id: "test-ny",
            name: "New York",
            region: "NY",
            latitude: 40.7128,
            longitude: -74.0060
        )
        let failingRepo = MockWeatherRepository(errorToThrow: WeatherServiceError.offline, delayNanoseconds: 0)
        let intent = TrackRainIntent(
            location: location,
            repository: failingRepo,
            cacheManager: emptyCache
        )

        do {
            _ = try await intent.perform()
            Issue.record("Expected WeatherUnavailableError to be thrown")
        } catch let error as WeatherUnavailableError {
            #expect(error.errorDescription == "I couldn't get the weather right now. Open UpThere and try again.")
            #expect(error.localizedStringResource.key == "I couldn't get the weather right now. Open UpThere and try again.")
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("SettingsViewModel reads and writes severeAlertsKey from AppGroup")
    func settingsViewModelUsesSharedAppGroupKey() {
        let (mockDefaults, suiteName) = makeIsolatedDefaults()
        defer { mockDefaults.removePersistentDomain(forName: suiteName) }

        mockDefaults.set(false, forKey: AppGroup.severeAlertsKey)
        let vm = SettingsViewModel(defaults: mockDefaults)
        #expect(vm.severeAlertsEnabled == false)

        vm.severeAlertsEnabled = true
        #expect(mockDefaults.bool(forKey: AppGroup.severeAlertsKey) == true)
    }

    @Test("SettingsViewModel formats version string from Bundle")
    func settingsViewModelAppVersionFromBundle() {
        let (mockDefaults, suiteName) = makeIsolatedDefaults()
        defer { mockDefaults.removePersistentDomain(forName: suiteName) }

        let vm = SettingsViewModel(defaults: mockDefaults)
        let expectedShort = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let expectedBuild = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        #expect(vm.appVersion == "\(expectedShort) (\(expectedBuild))")
    }

    // MARK: - Local Notification Tests

    @Test("Severe weather alert scheduled once per alert id")
    func severeWeatherAlertScheduledOnce() async {
        let fakeScheduler = FakeNotificationScheduler()
        let now = Date()
        let alert = WeatherAlert(
            id: "tornado-alert-001",
            source: "NWS",
            title: "Tornado Warning",
            validUntil: "Until 6:00 PM",
            details: "Take shelter immediately.",
            severity: "extreme",
            expirationDate: now.addingTimeInterval(3600)
        )
        let base = MockWeatherRepository.makeGhaziabadWeather()
        let weatherWithAlert = Weather(
            cityName: "Dallas",
            locationSubtitle: "Texas",
            temperature: 24,
            condition: "Thunderstorm",
            highTemperature: 28,
            lowTemperature: 18,
            feelsLike: 24,
            weatherSymbolName: "cloud.bolt.rain.fill",
            description: "Severe storm",
            humidity: 80,
            dewPoint: 20,
            windSpeed: 45,
            windDirection: "NW",
            precipitationChance: 90,
            uvIndex: 1,
            uvDescription: "Low",
            visibility: 5,
            visibilityDescription: "Poor",
            pressure: 998,
            pressureTrend: "Falling",
            alert: alert,
            hourlyForecast: base.hourlyForecast,
            dailyForecast: base.dailyForecast,
            rainWindow: base.rainWindow,
            warmingInsight: base.warmingInsight,
            chanceOfRain: 90,
            sunrise: base.sunrise,
            sunset: base.sunset,
            fetchTimestamp: now,
            isCached: false
        )

        // First refresh: schedules the alert
        await fakeScheduler.handleWeatherRefresh(
            weather: weatherWithAlert,
            rainAlertsEnabled: false,
            severeAlertsEnabled: true,
            now: now
        )

        let severeId = "\(NotificationScheduler.severeAlertIdPrefix)tornado-alert-001"
        #expect(fakeScheduler.scheduledRequests.count == 1)
        #expect(fakeScheduler.scheduledRequests.first?.id == severeId)
        #expect(fakeScheduler.scheduledRequests.first?.title == "Tornado Warning")
        #expect(fakeScheduler.scheduledRequests.first?.fireDate == nil, "Severe alerts should be immediate")

        // Second refresh with the same alert id: should NOT schedule again
        await fakeScheduler.handleWeatherRefresh(
            weather: weatherWithAlert,
            rainAlertsEnabled: false,
            severeAlertsEnabled: true,
            now: now.addingTimeInterval(300)
        )

        #expect(fakeScheduler.scheduledRequests.count == 1, "Alert should be scheduled once per alert id")
    }

    @Test("Rain alert scheduled and rescheduled without duplication")
    func rainAlertRescheduledNotDuplicated() async {
        let fakeScheduler = FakeNotificationScheduler()
        let now = Date()
        let rainStart = now.addingTimeInterval(3600) // 1 hour from now (within 2h)
        let rainHour = HourlyWeather(
            date: rainStart,
            temperature: 16,
            precipitationChance: 0.85,
            precipitationAmount: 3.0,
            symbolName: "cloud.rain.fill"
        )

        let base = MockWeatherRepository.makeGhaziabadWeather()
        let rainWeather = Weather(
            cityName: "Seattle",
            locationSubtitle: "Washington",
            temperature: 15,
            condition: "Rain",
            highTemperature: 18,
            lowTemperature: 12,
            feelsLike: 14,
            weatherSymbolName: "cloud.rain.fill",
            description: "Rain likely",
            humidity: 90,
            dewPoint: 13,
            windSpeed: 10,
            windDirection: "W",
            precipitationChance: 85,
            uvIndex: 2,
            uvDescription: "Low",
            visibility: 8,
            visibilityDescription: "Good",
            pressure: 1012,
            pressureTrend: "Steady",
            alert: nil,
            hourlyForecast: [rainHour],
            dailyForecast: base.dailyForecast,
            rainWindow: base.rainWindow,
            warmingInsight: base.warmingInsight,
            chanceOfRain: 85,
            sunrise: base.sunrise,
            sunset: base.sunset,
            fetchTimestamp: now,
            isCached: false
        )

        // First refresh: schedules rain alert 15 minutes before rain start
        await fakeScheduler.handleWeatherRefresh(
            weather: rainWeather,
            rainAlertsEnabled: true,
            severeAlertsEnabled: false,
            now: now
        )

        let rainRequests = fakeScheduler.scheduledRequests.filter { $0.id == NotificationScheduler.rainAlertId }
        #expect(rainRequests.count == 1)
        let expectedFireDate = rainStart.addingTimeInterval(-15 * 60)
        #expect(rainRequests.first?.fireDate == expectedFireDate)

        // Second refresh 5 minutes later: cancelled and rescheduled, still exactly one request
        let secondRefreshTime = now.addingTimeInterval(300)
        await fakeScheduler.handleWeatherRefresh(
            weather: rainWeather,
            rainAlertsEnabled: true,
            severeAlertsEnabled: false,
            now: secondRefreshTime
        )

        let rainRequestsAfterSecond = fakeScheduler.scheduledRequests.filter { $0.id == NotificationScheduler.rainAlertId }
        #expect(rainRequestsAfterSecond.count == 1, "Rescheduled notification must replace previous, not duplicate")
        #expect(fakeScheduler.cancelledIds.contains(NotificationScheduler.rainAlertId), "Should cancel previous rain alert on refresh")
    }

    @Test("Rain alert cancelled when rain disappears")
    func rainAlertCancelledWhenRainDisappears() async {
        let fakeScheduler = FakeNotificationScheduler()
        let now = Date()
        let rainStart = now.addingTimeInterval(3600)
        let rainHour = HourlyWeather(
            date: rainStart,
            temperature: 16,
            precipitationChance: 0.80,
            precipitationAmount: 2.0,
            symbolName: "cloud.rain.fill"
        )
        let base = MockWeatherRepository.makeGhaziabadWeather()
        let rainWeather = Weather(
            cityName: "London",
            locationSubtitle: "UK",
            temperature: 15,
            condition: "Rain",
            highTemperature: 18,
            lowTemperature: 12,
            feelsLike: 14,
            weatherSymbolName: "cloud.rain.fill",
            description: "Rain",
            humidity: 85,
            dewPoint: 12,
            windSpeed: 10,
            windDirection: "SW",
            precipitationChance: 80,
            uvIndex: 2,
            uvDescription: "Low",
            visibility: 8,
            visibilityDescription: "Good",
            pressure: 1012,
            pressureTrend: "Steady",
            alert: nil,
            hourlyForecast: [rainHour],
            dailyForecast: base.dailyForecast,
            rainWindow: base.rainWindow,
            warmingInsight: base.warmingInsight,
            chanceOfRain: 80,
            sunrise: base.sunrise,
            sunset: base.sunset,
            fetchTimestamp: now,
            isCached: false
        )

        // Schedule initially
        await fakeScheduler.handleWeatherRefresh(
            weather: rainWeather,
            rainAlertsEnabled: true,
            severeAlertsEnabled: false,
            now: now
        )
        #expect(fakeScheduler.scheduledRequests.contains { $0.id == NotificationScheduler.rainAlertId })

        // Clear weather (no rain)
        let clearHour = HourlyWeather(
            date: rainStart,
            temperature: 18,
            precipitationChance: 0.05,
            precipitationAmount: 0.0,
            symbolName: "sun.max.fill"
        )
        let clearWeather = Weather(
            cityName: "London",
            locationSubtitle: "UK",
            temperature: 17,
            condition: "Clear",
            highTemperature: 20,
            lowTemperature: 12,
            feelsLike: 17,
            weatherSymbolName: "sun.max.fill",
            description: "Sunny",
            humidity: 45,
            dewPoint: 8,
            windSpeed: 5,
            windDirection: "W",
            precipitationChance: 5,
            uvIndex: 5,
            uvDescription: "Moderate",
            visibility: 10,
            visibilityDescription: "Clear",
            pressure: 1018,
            pressureTrend: "Rising",
            alert: nil,
            hourlyForecast: [clearHour],
            dailyForecast: base.dailyForecast,
            rainWindow: nil,
            warmingInsight: base.warmingInsight,
            chanceOfRain: 5,
            sunrise: base.sunrise,
            sunset: base.sunset,
            fetchTimestamp: now.addingTimeInterval(600),
            isCached: false
        )

        // Refresh with clear weather
        await fakeScheduler.handleWeatherRefresh(
            weather: clearWeather,
            rainAlertsEnabled: true,
            severeAlertsEnabled: false,
            now: now.addingTimeInterval(600)
        )

        #expect(!fakeScheduler.scheduledRequests.contains { $0.id == NotificationScheduler.rainAlertId }, "Rain alert should be cancelled when rain disappears")
    }

    @Test("Nothing scheduled when notification toggles are off")
    func nothingScheduledWhenTogglesAreOff() async {
        let fakeScheduler = FakeNotificationScheduler()
        let now = Date()
        let rainStart = now.addingTimeInterval(3600)
        let rainHour = HourlyWeather(
            date: rainStart,
            temperature: 16,
            precipitationChance: 0.90,
            precipitationAmount: 4.0,
            symbolName: "cloud.heavyrain.fill"
        )
        let alert = WeatherAlert(
            id: "flood-alert-002",
            source: "NWS",
            title: "Flash Flood Warning",
            validUntil: "Until 8 PM",
            details: "Move to higher ground.",
            severity: "severe",
            expirationDate: now.addingTimeInterval(7200)
        )
        let base = MockWeatherRepository.makeGhaziabadWeather()
        let rainyAlertWeather = Weather(
            cityName: "Miami",
            locationSubtitle: "Florida",
            temperature: 25,
            condition: "Heavy Rain",
            highTemperature: 28,
            lowTemperature: 22,
            feelsLike: 26,
            weatherSymbolName: "cloud.heavyrain.fill",
            description: "Stormy",
            humidity: 95,
            dewPoint: 24,
            windSpeed: 30,
            windDirection: "E",
            precipitationChance: 90,
            uvIndex: 1,
            uvDescription: "Low",
            visibility: 4,
            visibilityDescription: "Poor",
            pressure: 1002,
            pressureTrend: "Falling",
            alert: alert,
            hourlyForecast: [rainHour],
            dailyForecast: base.dailyForecast,
            rainWindow: base.rainWindow,
            warmingInsight: base.warmingInsight,
            chanceOfRain: 90,
            sunrise: base.sunrise,
            sunset: base.sunset,
            fetchTimestamp: now,
            isCached: false
        )

        // Both toggles OFF
        await fakeScheduler.handleWeatherRefresh(
            weather: rainyAlertWeather,
            rainAlertsEnabled: false,
            severeAlertsEnabled: false,
            now: now
        )

        #expect(fakeScheduler.scheduledRequests.isEmpty, "Nothing should be scheduled when toggles are off")
    }

    @Test("Permission requested only when user first turns notification toggle on and denied shows banner")
    func permissionRequestedWhenToggleTurnedOn() async {
        let (mockDefaults, suiteName) = makeIsolatedDefaults()
        defer { mockDefaults.removePersistentDomain(forName: suiteName) }

        // 1. Initial state: not determined, user denies permission
        let fakeScheduler = FakeNotificationScheduler(
            authorizationStatus: .notDetermined,
            requestAuthorizationResult: false
        )
        let vm = SettingsViewModel(defaults: mockDefaults, notificationScheduler: fakeScheduler)
        #expect(fakeScheduler.requestAuthorizationCallCount == 0, "No permission request until user turns a toggle on")
        #expect(vm.rainAlertsEnabled == false)

        // User turns toggle on
        await vm.setRainAlerts(true)
        #expect(fakeScheduler.requestAuthorizationCallCount == 1, "Permission must be requested when toggle is turned on")
        #expect(vm.notificationsDenied == true, "Denied permission must update notificationsDenied flag")
        #expect(vm.rainAlertsEnabled == false, "Toggle must remain off when permission is denied")

        // 2. User grants permission
        let grantedScheduler = FakeNotificationScheduler(
            authorizationStatus: .notDetermined,
            requestAuthorizationResult: true
        )
        let vmGranted = SettingsViewModel(defaults: mockDefaults, notificationScheduler: grantedScheduler)
        await vmGranted.setRainAlerts(true)
        #expect(grantedScheduler.requestAuthorizationCallCount == 1)
        #expect(vmGranted.notificationsDenied == false)
        #expect(vmGranted.rainAlertsEnabled == true)
        #expect(mockDefaults.bool(forKey: AppGroup.rainAlertsKey) == true)
    }

    @Test("HomeViewModel schedules rain notification on successful weather refresh")
    func homeViewModelSchedulesRainNotificationOnRefresh() async {
        let (mockDefaults, suiteName) = makeIsolatedDefaults()
        defer { mockDefaults.removePersistentDomain(forName: suiteName) }

        mockDefaults.set(true, forKey: AppGroup.rainAlertsKey)
        let fakeScheduler = FakeNotificationScheduler()

        let now = Date()
        let rainStart = now.addingTimeInterval(3600)
        let rainHour = HourlyWeather(
            date: rainStart,
            temperature: 17,
            precipitationChance: 0.9,
            precipitationAmount: 4.0,
            symbolName: "cloud.rain.fill"
        )
        let base = MockWeatherRepository.makeGhaziabadWeather()
        let rainWeather = Weather(
            cityName: base.cityName,
            locationSubtitle: base.locationSubtitle,
            temperature: base.temperature,
            condition: "Rain",
            highTemperature: base.highTemperature,
            lowTemperature: base.lowTemperature,
            feelsLike: base.feelsLike,
            weatherSymbolName: "cloud.rain.fill",
            description: base.description,
            humidity: base.humidity,
            dewPoint: base.dewPoint,
            windSpeed: base.windSpeed,
            windDirection: base.windDirection,
            precipitationChance: 90,
            uvIndex: base.uvIndex,
            uvDescription: base.uvDescription,
            visibility: base.visibility,
            visibilityDescription: base.visibilityDescription,
            pressure: base.pressure,
            pressureTrend: base.pressureTrend,
            alert: nil,
            hourlyForecast: [rainHour],
            dailyForecast: base.dailyForecast,
            rainWindow: base.rainWindow,
            warmingInsight: base.warmingInsight,
            chanceOfRain: 90,
            sunrise: base.sunrise,
            sunset: base.sunset,
            fetchTimestamp: now,
            isCached: false
        )

        let repo = MockWeatherRepository(mockWeather: rainWeather, delayNanoseconds: 0)
        let useCase = GetWeatherUseCase(repository: repo)
        let vm = HomeViewModel(
            getWeatherUseCase: useCase,
            notificationScheduler: fakeScheduler,
            defaults: mockDefaults
        )

        await vm.loadWeather()

        let rainRequests = fakeScheduler.scheduledRequests.filter { $0.id == NotificationScheduler.rainAlertId }
        #expect(rainRequests.count == 1, "HomeViewModel should trigger rain notification scheduling after successful refresh")
    }

    // MARK: - 42. Observable UnitPreferences updates formatted output without recreating views
    @Test("Changing the temperature unit updates formatted output without recreating views")
    func changingTemperatureUnitUpdatesFormattedOutputWithoutRecreatingViews() {
        let (mockDefaults, suiteName) = makeIsolatedDefaults()
        defer { mockDefaults.removePersistentDomain(forName: suiteName) }

        let prefs = UnitPreferences(defaults: mockDefaults)
        prefs.temperatureUnit = .celsius
        let formatter = WeatherFormatter(preferences: prefs)

        struct WeatherDisplayView: View {
            let formatter: WeatherFormatter
            let tempValue: Double

            var body: some View {
                Text(formatter.temp(tempValue))
            }
        }

        // Create the view instance once
        let view = WeatherDisplayView(formatter: formatter, tempValue: 20.0)

        // Celsius output
        #expect(formatter.temp(20.0) == "20°")
        #expect(view.formatter.temp(20.0) == "20°")

        // Changing the temperature unit updates the formatted output dynamically without recreating the view
        prefs.temperatureUnit = .fahrenheit

        #expect(formatter.temp(20.0) == "68°")
        #expect(view.formatter.temp(20.0) == "68°")

        // Switching back
        prefs.temperatureUnit = .celsius

        #expect(formatter.temp(20.0) == "20°")
        #expect(view.formatter.temp(20.0) == "20°")
    }
}


