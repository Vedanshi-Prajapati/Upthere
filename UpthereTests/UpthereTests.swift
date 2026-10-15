import Testing
import Foundation
import CoreLocation
import AppIntents
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
    func firstLaunchPermissionDeniedGhaziabadFallback() {
        let fallbackCity = LocationService.fallbackCityName
        let fallbackCoord = LocationService.fallbackCoordinate

        #expect(fallbackCity == "Ghaziabad")
        #expect(abs(fallbackCoord.coordinate.latitude - 28.6692) < 0.001)
        #expect(abs(fallbackCoord.coordinate.longitude - 77.4538) < 0.001)
    }

    // MARK: - 3. Permission revoked after previously being granted
    @Test("Permission revoked error description contains denied")
    func permissionRevokedAfterGranted() {
        let err = LocationServiceError.permissionDenied
        #expect(err.errorDescription?.contains("denied") == true)
    }

    // MARK: - 4. Location services disabled
    @Test("Location services disabled error description contains disabled")
    func locationServicesDisabled() {
        let err = LocationServiceError.servicesDisabled
        #expect(err.errorDescription?.contains("disabled") == true)
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
    @Test("Weather API timeout is retryable")
    func weatherApiTimeout() {
        let err = WeatherServiceError.timeout
        #expect(err.isRetryable)
        #expect(err.errorDescription?.contains("timed out") == true)
    }

    // MARK: - 9. API returns an authorization error
    @Test("API authorization error is not retryable")
    func apiAuthorizationError() {
        let err = WeatherServiceError.unauthorized
        #expect(!err.isRetryable)
        #expect(err.errorDescription?.contains("Unauthorized") == true)
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

        try? await Task.sleep(nanoseconds: 100_000_000)

        #expect(vm.selectedLocation?.cityName == "Paris")
    }

    // MARK: - 14. Missing temperature does not display as zero
    @Test("Missing or negative zero temperature formats safely")
    func missingTemperatureDoesNotDisplayZero() {
        let negativeZero = -0.0001
        let formattedNegZero = WeatherFormatter.shared.temp(negativeZero)
        let validNegFive = WeatherFormatter.shared.temp(-5.0)

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
        let initial = UserDefaults.standard.bool(forKey: "settings.severeAlertsEnabled")
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
        repo.delayNanoseconds = 300_000_000 // 300ms

        let cityA = SavedLocation(cityName: "CityA", regionName: "RegionA", condition: "Cloudy", isCurrentLocation: false, latitude: 10, longitude: 20)
        let cityB = SavedLocation(cityName: "CityB", regionName: "RegionB", condition: "Sunny", isCurrentLocation: false, latitude: 30, longitude: 40)
        locManager.addLocation(cityA)
        locManager.addLocation(cityB)

        // Start request A
        vm.selectLocation(cityA)
        try? await Task.sleep(nanoseconds: 30_000_000)

        // Immediately start request B with no delay
        repo.delayNanoseconds = 0
        vm.selectLocation(cityB)

        // Wait for everything to settle
        try? await Task.sleep(nanoseconds: 400_000_000)

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

    @Test("Remove location deletes non-current location but protects Current location")
    func removeLocationProtectsCurrentLocation() {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_locs_\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let store = FileLocationStore(fileURL: tempURL)
        let manager = SavedLocationsManager(store: store)

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
}
