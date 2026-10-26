import Testing
import Foundation
import CoreLocation
import AppIntents
import SwiftUI
import WidgetKit
@testable import Upthere

@Suite("Cache Tests")
@MainActor
struct CacheTests {

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

}
