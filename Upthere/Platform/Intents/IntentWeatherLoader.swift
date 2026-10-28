import Foundation
import CoreLocation
import os

/// Resolved location details from an optional LocationEntity parameter.
struct IntentResolvedLocation: Equatable, Sendable {
    let cityName: String
    let coordinate: CLLocationCoordinate2D
    let isCurrentLocation: Bool

    init(cityName: String, coordinate: CLLocationCoordinate2D, isCurrentLocation: Bool) {
        self.cityName = cityName
        self.coordinate = coordinate
        self.isCurrentLocation = isCurrentLocation
    }

    var locationSubtitle: String {
        isCurrentLocation ? "Current Location" : ""
    }

    static func == (lhs: IntentResolvedLocation, rhs: IntentResolvedLocation) -> Bool {
        lhs.cityName == rhs.cityName &&
        lhs.coordinate.latitude == rhs.coordinate.latitude &&
        lhs.coordinate.longitude == rhs.coordinate.longitude &&
        lhs.isCurrentLocation == rhs.isCurrentLocation
    }
}

/// Protocol abstracting weather loading and location resolution for AppIntents.
@MainActor
protocol IntentWeatherLoading: Sendable {
    func resolveLocation(_ location: LocationEntity?) -> IntentResolvedLocation
    func loadWeather(
        for location: LocationEntity?,
        repository: (any WeatherRepository)?,
        cacheManager: WeatherCacheManager?
    ) async throws -> (weather: Weather, location: IntentResolvedLocation)
}

/// Shared helper for loading live or cached weather across AppIntents.
@MainActor
final class IntentWeatherLoader: IntentWeatherLoading {
    private let locationService: LocationService

    init(locationService: LocationService = .shared) {
        self.locationService = locationService
    }

    func resolveLocation(_ location: LocationEntity?) -> IntentResolvedLocation {
        let targetCity: String
        let coordinate: CLLocationCoordinate2D
        let isCurrent: Bool

        if let loc = location, loc.id != "current" {
            targetCity = loc.name
            coordinate = CLLocationCoordinate2D(latitude: loc.latitude, longitude: loc.longitude)
            isCurrent = false
        } else {
            targetCity = locationService.currentCityName
            coordinate = locationService.currentLocation?.coordinate ?? LocationService.fallbackCoordinate.coordinate
            isCurrent = true
        }

        return IntentResolvedLocation(
            cityName: targetCity,
            coordinate: coordinate,
            isCurrentLocation: isCurrent
        )
    }

    func loadWeather(
        for location: LocationEntity?,
        repository: (any WeatherRepository)? = nil,
        cacheManager: WeatherCacheManager? = nil
    ) async throws -> (weather: Weather, location: IntentResolvedLocation) {
        let resolved = resolveLocation(location)
        let cache = cacheManager ?? WeatherCacheManager.shared
        let repo = repository ?? WeatherKitWeatherRepository(locationService: locationService, cacheManager: cache)

        let weather: Weather
        do {
            weather = try await repo.fetchWeather(
                for: CLLocation(latitude: resolved.coordinate.latitude, longitude: resolved.coordinate.longitude),
                cityName: resolved.cityName,
                locationSubtitle: resolved.locationSubtitle
            )
        } catch {
            let logger = Logger(subsystem: "com.vedanshi.upthereapp", category: "IntentWeatherLoader")
            logger.error("Failed to fetch weather for intent: \(error.localizedDescription)")
            let coordKey = cache.cacheKey(
                for: resolved.cityName,
                coordinate: (lat: resolved.coordinate.latitude, lon: resolved.coordinate.longitude)
            )
            let cityKey = cache.cacheKey(for: resolved.cityName)
            let cachedCoord = cache.load(key: coordKey, allowExpired: true)?.weather
            let cachedCity = cache.load(key: cityKey, allowExpired: true)?.weather
            if let cached = cachedCoord ?? cachedCity {
                weather = cached
            } else {
                throw WeatherUnavailableError()
            }
        }

        return (weather, resolved)
    }
}
