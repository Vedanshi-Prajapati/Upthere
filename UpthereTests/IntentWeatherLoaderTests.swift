import Testing
import Foundation
import CoreLocation
@testable import Upthere

@Suite("IntentWeatherLoader Tests")
@MainActor
struct IntentWeatherLoaderTests {

    @Test("Resolves current location when LocationEntity is nil")
    func resolvesCurrentLocationWhenNil() {
        let fakeManager = FakeLocationManager()
        let service = LocationService(manager: fakeManager, isLocationServicesEnabledProvider: { true })
        let loader = IntentWeatherLoader(locationService: service)

        let resolved = loader.resolveLocation(nil)
        #expect(resolved.isCurrentLocation == true)
        #expect(resolved.locationSubtitle == "Current Location")
        #expect(resolved.cityName == service.currentCityName)
        #expect(resolved.coordinate.latitude == LocationService.fallbackCoordinate.coordinate.latitude)
        #expect(resolved.coordinate.longitude == LocationService.fallbackCoordinate.coordinate.longitude)
    }

    @Test("Resolves current location when LocationEntity id is 'current'")
    func resolvesCurrentLocationWhenIdIsCurrent() {
        let fakeManager = FakeLocationManager()
        let service = LocationService(manager: fakeManager, isLocationServicesEnabledProvider: { true })
        let loader = IntentWeatherLoader(locationService: service)

        let entity = LocationEntity(
            id: "current",
            name: "Current GPS",
            region: "",
            latitude: 12.34,
            longitude: 56.78
        )

        let resolved = loader.resolveLocation(entity)
        #expect(resolved.isCurrentLocation == true)
        #expect(resolved.locationSubtitle == "Current Location")
        #expect(resolved.cityName == service.currentCityName)
    }

    @Test("Resolves custom city when non-current LocationEntity is provided")
    func resolvesCustomLocation() {
        let fakeManager = FakeLocationManager()
        let service = LocationService(manager: fakeManager, isLocationServicesEnabledProvider: { true })
        let loader = IntentWeatherLoader(locationService: service)

        let entity = LocationEntity(
            id: "tokyo-1",
            name: "Tokyo",
            region: "Japan",
            latitude: 35.6762,
            longitude: 139.6503
        )

        let resolved = loader.resolveLocation(entity)
        #expect(resolved.isCurrentLocation == false)
        #expect(resolved.locationSubtitle == "")
        #expect(resolved.cityName == "Tokyo")
        #expect(resolved.coordinate.latitude == 35.6762)
        #expect(resolved.coordinate.longitude == 139.6503)
    }

    @Test("Loads live weather successfully when repository succeeds")
    func loadsLiveWeatherSuccessfully() async throws {
        let fakeManager = FakeLocationManager()
        let service = LocationService(manager: fakeManager, isLocationServicesEnabledProvider: { true })
        let loader = IntentWeatherLoader(locationService: service)

        let expectedWeather = MockWeatherRepository.makeGhaziabadWeather().withCityName("Berlin")
        let repo = MockWeatherRepository(mockWeather: expectedWeather, delayNanoseconds: 0)

        let (weather, resolved) = try await loader.loadWeather(
            for: LocationEntity(id: "berlin", name: "Berlin", region: "Germany", latitude: 52.52, longitude: 13.405),
            repository: repo
        )

        #expect(weather.cityName == "Berlin")
        #expect(resolved.cityName == "Berlin")
        #expect(repo.fetchCallCount == 1)
    }

    @Test("Falls back to coordinate cache when repository fails")
    func fallsBackToCoordinateCache() async throws {
        let (mockDefaults, suiteName) = makeIsolatedDefaults()
        defer { mockDefaults.removePersistentDomain(forName: suiteName) }

        let cache = WeatherCacheManager(defaults: mockDefaults)
        let location = LocationEntity(
            id: "paris",
            name: "Paris",
            region: "France",
            latitude: 48.8566,
            longitude: 2.3522
        )

        let cachedWeather = MockWeatherRepository.makeGhaziabadWeather().withCityName("Paris")
        let coordKey = cache.cacheKey(for: location.name, coordinate: (lat: location.latitude, lon: location.longitude))
        cache.save(weather: cachedWeather, key: coordKey)

        let failingRepo = MockWeatherRepository(errorToThrow: WeatherServiceError.offline, delayNanoseconds: 0)
        let loader = IntentWeatherLoader()

        let (weather, resolved) = try await loader.loadWeather(
            for: location,
            repository: failingRepo,
            cacheManager: cache
        )

        #expect(weather.cityName == "Paris")
        #expect(resolved.cityName == "Paris")
    }

    @Test("Falls back to city key cache when coordinate key is missing")
    func fallsBackToCityKeyCache() async throws {
        let (mockDefaults, suiteName) = makeIsolatedDefaults()
        defer { mockDefaults.removePersistentDomain(forName: suiteName) }

        let cache = WeatherCacheManager(defaults: mockDefaults)
        let location = LocationEntity(
            id: "mumbai",
            name: "Mumbai",
            region: "India",
            latitude: 19.0760,
            longitude: 72.8777
        )

        let cachedWeather = MockWeatherRepository.makeGhaziabadWeather().withCityName("Mumbai")
        let cityKey = cache.cacheKey(for: location.name)
        cache.save(weather: cachedWeather, key: cityKey)

        let failingRepo = MockWeatherRepository(errorToThrow: WeatherServiceError.offline, delayNanoseconds: 0)
        let loader = IntentWeatherLoader()

        let (weather, resolved) = try await loader.loadWeather(
            for: location,
            repository: failingRepo,
            cacheManager: cache
        )

        #expect(weather.cityName == "Mumbai")
        #expect(resolved.cityName == "Mumbai")
    }

    @Test("Throws WeatherUnavailableError when both network and cache fail")
    func throwsWhenBothNetworkAndCacheFail() async {
        let (mockDefaults, suiteName) = makeIsolatedDefaults()
        defer { mockDefaults.removePersistentDomain(forName: suiteName) }

        let emptyCache = WeatherCacheManager(defaults: mockDefaults)
        let location = LocationEntity(
            id: "oslo",
            name: "Oslo",
            region: "Norway",
            latitude: 59.9139,
            longitude: 10.7522
        )

        let failingRepo = MockWeatherRepository(errorToThrow: WeatherServiceError.offline, delayNanoseconds: 0)
        let loader = IntentWeatherLoader()

        do {
            _ = try await loader.loadWeather(
                for: location,
                repository: failingRepo,
                cacheManager: emptyCache
            )
            Issue.record("Expected WeatherUnavailableError to be thrown")
        } catch is WeatherUnavailableError {
            // Success
        } catch {
            Issue.record("Unexpected error thrown: \(error)")
        }
    }

    // MARK: - Dialog & Snippet Builder Tests

    @Test("Dialog builder formats check weather strings identically")
    func checkWeatherDialogFormatting() {
        let weather = Weather(
            cityName: "London",
            temperature: 18.4,
            condition: "Partly Cloudy",
            highTemperature: 22.1,
            lowTemperature: 12.8,
            chanceOfRain: 40
        )

        let summary = IntentDialogSnippetBuilder.checkWeatherSummaryValue(for: weather)
        #expect(summary == "London: 18°, Partly Cloudy")

        let dialog = IntentDialogSnippetBuilder.checkWeatherDialogText(for: weather)
        #expect(dialog == "It's currently 18° and Partly Cloudy in London, with a high of 22°, low of 13°, and 40% chance of rain.")
    }

    @Test("Dialog builder formats track rain strings identically")
    func trackRainDialogFormatting() {
        let noRain = IntentDialogSnippetBuilder.trackRainNoRainDialog(city: "Seattle")
        #expect(noRain == "No rain expected within the next 2 hours in Seattle.")

        let rainUpcoming = IntentDialogSnippetBuilder.trackRainStartedDialog(city: "Seattle", minutesUntilRain: 25)
        #expect(rainUpcoming == "Tracking rain for Seattle. Rain starting in 25 minutes.")

        let rainNow = IntentDialogSnippetBuilder.trackRainStartedDialog(city: "Seattle", minutesUntilRain: 0)
        #expect(rainNow == "Tracking rain for Seattle. Rain is currently in progress.")

        let unable = IntentDialogSnippetBuilder.trackRainUnableToStartDialog()
        #expect(unable == "Unable to start rain tracking. Please ensure Live Activities are enabled in Settings.")
    }
}
