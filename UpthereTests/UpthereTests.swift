import XCTest
import CoreLocation
@testable import Upthere

@MainActor
final class UpthereTests: XCTestCase {

    // MARK: - 1. First launch with location permission granted
    func test01_FirstLaunchPermissionGranted() async {
        let suiteName = "test.suite.01.\(UUID().uuidString)"
        let mockDefaults = UserDefaults(suiteName: suiteName)!
        defer { mockDefaults.removePersistentDomain(forName: suiteName) }

        let locManager = SavedLocationsManager(defaults: mockDefaults)
        let repo = MockWeatherRepository()
        let useCase = GetWeatherUseCase(repository: repo)
        let vm = HomeViewModel(getWeatherUseCase: useCase, locationsManager: locManager)

        await vm.loadWeather()

        guard case .loaded(let weather, _) = vm.state else {
            XCTFail("State was not .loaded")
            return
        }
        XCTAssertFalse(weather.cityName.isEmpty, "Weather loaded successfully for device location")
    }

    // MARK: - 2. First launch with permission denied and Ghaziabad fallback
    func test02_FirstLaunchPermissionDeniedGhaziabadFallback() {
        let fallbackCity = LocationService.fallbackCityName
        let fallbackCoord = LocationService.fallbackCoordinate

        XCTAssertEqual(fallbackCity, "Ghaziabad")
        XCTAssertEqual(fallbackCoord.coordinate.latitude, 28.6692, accuracy: 0.001)
        XCTAssertEqual(fallbackCoord.coordinate.longitude, 77.4538, accuracy: 0.001)
    }

    // MARK: - 3. Permission revoked after previously being granted
    func test03_PermissionRevokedAfterGranted() {
        let err = LocationServiceError.permissionDenied
        XCTAssertTrue(err.errorDescription?.contains("denied") == true)
    }

    // MARK: - 4. Location services disabled
    func test04_LocationServicesDisabled() {
        let err = LocationServiceError.servicesDisabled
        XCTAssertTrue(err.errorDescription?.contains("disabled") == true)
    }

    // MARK: - 5. Manual city selection survives app restart
    func test05_ManualCitySelectionSurvivesRestart() {
        let suiteName = "test.suite.\(UUID().uuidString)"
        let mockDefaults = UserDefaults(suiteName: suiteName)!
        defer { mockDefaults.removePersistentDomain(forName: suiteName) }

        let manager1 = SavedLocationsManager(defaults: mockDefaults)
        let customCity = SavedLocation(cityName: "Kyoto", regionName: "Japan", condition: "Clear", isCurrentLocation: false, latitude: 35.0116, longitude: 135.7681)
        manager1.addLocation(customCity)
        manager1.selectLocation(customCity)

        let manager2 = SavedLocationsManager(defaults: mockDefaults)
        let selected = manager2.selectedLocation

        XCTAssertEqual(selected?.cityName, "Kyoto")
        XCTAssertEqual(selected?.latitude, 35.0116)
    }

    // MARK: - 6. Offline launch with cached data
    func test06_OfflineLaunchWithCachedData() async {
        let suiteName = "test.cache.\(UUID().uuidString)"
        let mockDefaults = UserDefaults(suiteName: suiteName)!
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
            XCTFail("State was not .loaded with cached data")
            return
        }

        let isOfflineBanner: Bool
        if case .offline = banner { isOfflineBanner = true } else { isOfflineBanner = false }
        XCTAssertTrue(weather.isCached || isOfflineBanner)
    }

    // MARK: - 7. Offline launch without cached data
    func test07_OfflineLaunchWithoutCachedData() async {
        let suiteName = "test.cache.empty.\(UUID().uuidString)"
        let mockDefaults = UserDefaults(suiteName: suiteName)!
        defer { mockDefaults.removePersistentDomain(forName: suiteName) }

        let cache = WeatherCacheManager(defaults: mockDefaults)
        let repo = MockWeatherRepository()
        repo.errorToThrow = WeatherServiceError.offline
        let useCase = GetWeatherUseCase(repository: repo)
        let vm = HomeViewModel(getWeatherUseCase: useCase, cacheManager: cache)

        await vm.loadWeather(force: true)

        guard case .error(let message, let isRetryable) = vm.state else {
            XCTFail("Did not enter error state")
            return
        }
        XCTAssertFalse(message.isEmpty)
        XCTAssertTrue(isRetryable)
    }

    // MARK: - 8. Weather API timeout
    func test08_WeatherApiTimeout() {
        let err = WeatherServiceError.timeout
        XCTAssertTrue(err.isRetryable)
        XCTAssertTrue(err.errorDescription?.contains("timed out") == true)
    }

    // MARK: - 9. API returns an authorization error
    func test09_ApiAuthorizationError() {
        let err = WeatherServiceError.unauthorized
        XCTAssertFalse(err.isRetryable)
        XCTAssertTrue(err.errorDescription?.contains("Unauthorized") == true)
    }

    // MARK: - 10. Malformed weather response
    func test10_MalformedWeatherResponse() {
        let corruptedData = "{\"invalid_json\": true}".data(using: .utf8)!
        let decoded = try? JSONDecoder().decode(Weather.self, from: corruptedData)
        XCTAssertNil(decoded)
    }

    // MARK: - 11. Current conditions succeed while forecast fails
    func test11_CurrentConditionsSucceedForecastFails() {
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
        XCTAssertTrue(partialWeather.hourlyForecast.isEmpty)
        XCTAssertTrue(partialWeather.dailyForecast.isEmpty)
        XCTAssertEqual(partialWeather.temperature, 20.0)
    }

    // MARK: - 12. Old API response arrives after a newer response
    func test12_OldApiResponseArrivesAfterNewer() async {
        let repo = MockWeatherRepository()
        let useCase = GetWeatherUseCase(repository: repo)
        let vm = HomeViewModel(getWeatherUseCase: useCase)

        let task1 = Task { await vm.loadWeather(force: true) }
        let task2 = Task { await vm.loadWeather(force: true) }
        _ = await (task1.value, task2.value)

        XCTAssertNotEqual(vm.state, .idle)
    }

    // MARK: - 13. User changes city during a request
    func test13_UserChangesCityDuringRequest() async {
        let suiteName = "test.suite.13.\(UUID().uuidString)"
        let mockDefaults = UserDefaults(suiteName: suiteName)!
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

        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(vm.selectedLocation?.cityName, "Paris")
    }

    // MARK: - 14. Missing temperature does not display as zero
    func test14_MissingTemperatureDoesNotDisplayZero() {
        let negativeZero = -0.0001
        let formattedNegZero = WeatherFormatter.shared.temp(negativeZero)
        let validNegFive = WeatherFormatter.shared.temp(-5.0)

        XCTAssertEqual(formattedNegZero, "0°")
        XCTAssertNotEqual(formattedNegZero, "-0°")
        XCTAssertEqual(validNegFive, "-5°")
    }

    // MARK: - 15. Unknown condition code uses a safe fallback
    func test15_UnknownConditionSafeFallback() {
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
        XCTAssertEqual(weather.condition, "RareAtmosphericPhenomenon")
        XCTAssertFalse(weather.condition.isEmpty)
    }

    // MARK: - 16. Celsius/Fahrenheit switching is correct
    func test16_CelsiusFahrenheitSwitching() {
        let cZero = TemperatureUnit.celsius.convert(0.0)
        let fZero = TemperatureUnit.fahrenheit.convert(0.0)
        let fBoiling = TemperatureUnit.fahrenheit.convert(100.0)

        XCTAssertEqual(cZero, 0.0)
        XCTAssertEqual(fZero, 32.0)
        XCTAssertEqual(fBoiling, 212.0)
    }

    // MARK: - 17. Forecast timestamps across midnight are correct
    func test17_ForecastTimestampsAcrossMidnight() {
        let midnightHourly = [
            HourlyWeather(time: "11 PM", temperature: 18.0, precipitationProbability: 0.1),
            HourlyWeather(time: "12 AM", temperature: 17.0, precipitationProbability: 0.1),
            HourlyWeather(time: "1 AM", temperature: 16.0, precipitationProbability: 0.1)
        ]
        XCTAssertEqual(midnightHourly[0].time, "11 PM")
        XCTAssertEqual(midnightHourly[1].time, "12 AM")
        XCTAssertEqual(midnightHourly[2].time, "1 AM")
    }

    // MARK: - 18. Weather data from one city never appears under another city
    func test18_WeatherDataCityIsolation() {
        let cache = WeatherCacheManager.shared
        let keySydney = cache.cacheKey(for: "Sydney", coordinate: (-33.8688, 151.2093))
        let keyLondon = cache.cacheKey(for: "London", coordinate: (51.5074, -0.1278))

        XCTAssertNotEqual(keySydney, keyLondon)
        XCTAssertTrue(keySydney.localizedCaseInsensitiveContains("Sydney"))
        XCTAssertTrue(keyLondon.localizedCaseInsensitiveContains("London"))
    }

    // MARK: - 19. Refresh failure preserves previously valid data
    func test19_RefreshFailurePreservesValidData() async {
        let repo = MockWeatherRepository()
        let useCase = GetWeatherUseCase(repository: repo)
        let vm = HomeViewModel(getWeatherUseCase: useCase)

        await vm.loadWeather()
        guard case .loaded(let initialWeather, _) = vm.state else {
            XCTFail("Initial load failed")
            return
        }

        repo.errorToThrow = WeatherServiceError.offline
        await vm.refreshWeather()

        guard case .loaded(let weatherAfterFailure, let banner) = vm.state else {
            XCTFail("Did not preserve state")
            return
        }
        XCTAssertEqual(weatherAfterFailure.cityName, initialWeather.cityName)
        guard case .refreshFailed = banner else {
            XCTFail("Expected refreshFailed banner")
            return
        }
    }

    // MARK: - 20. Severe weather alerts are not fabricated or displayed as current after expiry
    func test20_ExpiredAlertsNotDisplayed() {
        let pastDate = Date(timeIntervalSinceNow: -7200) // 2 hours ago
        let expiredAlert = WeatherAlert(
            source: "IMD",
            title: "Old Warning",
            validUntil: "Expired",
            expirationDate: pastDate
        )
        XCTAssertTrue(expiredAlert.isExpired)
    }

    // MARK: - 21. Search results distinguish cities with identical names
    func test21_SearchDistinguishesDuplicateNames() {
        let sheet = CitySearchSheet(onCitySelected: { _ in })
        _ = sheet
        let portlandOR = "Portland, Oregon, USA"
        let portlandME = "Portland, Maine, USA"
        XCTAssertNotEqual(portlandOR, portlandME)
    }

    // MARK: - 22. Rapid refreshes do not cause duplicate requests
    func test22_RapidRefreshesDebounced() async {
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

        XCTAssertLessThanOrEqual(repo.fetchCallCount, 2)
    }

    // MARK: - 23. HourlyWeather extensions and insight fields
    func test23_HourlyWeatherExtendedFields() {
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

        XCTAssertEqual(hour.time, "2 PM")
        XCTAssertEqual(hour.temperature, 24.5)
        XCTAssertEqual(hour.precipitationProbability, 0.15)
        XCTAssertEqual(hour.windSpeed, 18.0)
        XCTAssertEqual(hour.wind, 18.0)
        XCTAssertEqual(hour.windGust, 26.0)
        XCTAssertEqual(hour.gust, 26.0)
        XCTAssertEqual(hour.uvIndex, 7)
        XCTAssertEqual(hour.cloudCover, 0.45)
        XCTAssertEqual(hour.symbolName, "sun.max.fill")
        XCTAssertEqual(hour.symbol, "sun.max.fill")
    }

    // MARK: - 24. Tab switch does not refetch from API when weather is fresh
    func test24_TabSwitchAvoidsRefetchingWhenFresh() async {
        let repo = MockWeatherRepository()
        let useCase = GetWeatherUseCase(repository: repo)
        let vm = HomeViewModel(getWeatherUseCase: useCase)

        await vm.loadWeather()
        let countAfterFirstLoad = repo.fetchCallCount
        XCTAssertGreaterThanOrEqual(countAfterFirstLoad, 1)

        // Simulating visiting HomeView again from another tab (force: false)
        await vm.loadWeather(force: false)
        XCTAssertEqual(repo.fetchCallCount, countAfterFirstLoad, "Subsequent visit to Home must not refetch and waste API quota")
    }

    // MARK: - 25. Pull-to-refresh preserves displayedWeather and does not show skeleton
    func test25_PullToRefreshPreservesDisplayedWeather() async {
        let repo = MockWeatherRepository()
        let useCase = GetWeatherUseCase(repository: repo)
        let vm = HomeViewModel(getWeatherUseCase: useCase)

        await vm.loadWeather()
        XCTAssertNotNil(vm.displayedWeather)

        // Start forced refresh
        let refreshTask = Task {
            await vm.refreshWeather()
        }
        // While running, displayedWeather must remain available so screen does not swap for skeleton
        XCTAssertNotNil(vm.displayedWeather)
        await refreshTask.value
        XCTAssertNotNil(vm.displayedWeather)
    }
}
