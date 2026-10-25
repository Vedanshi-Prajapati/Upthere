import Foundation
import CoreLocation
import WeatherKit
import os

@MainActor
final class WeatherKitWeatherRepository: WeatherRepository {
    private let weatherService: WeatherService
    private let locationService: LocationService
    private let cacheManager: WeatherCacheManager

    init(
        weatherService: WeatherService? = nil,
        locationService: LocationService? = nil,
        cacheManager: WeatherCacheManager? = nil
    ) {
        self.weatherService = weatherService ?? .shared
        self.locationService = locationService ?? .shared
        self.cacheManager = cacheManager ?? .shared
    }

    func fetchCurrentWeather() async throws -> Weather {
        let location: CLLocation
        let cityName: String
        let subtitle: String

        do {
            let userLoc = try await locationService.requestCurrentLocation(force: true)
            location = userLoc
            let geo = await locationService.reverseGeocode(location: userLoc)
            cityName = geo.cityName
            subtitle = geo.subtitle
        } catch {
            // Fall back strictly to Ghaziabad, Uttar Pradesh, India when device location cannot be obtained
            location = LocationService.fallbackCoordinate
            cityName = LocationService.fallbackCityName
            let reason: String
            if let locError = error as? LocationServiceError {
                switch locError {
                case .servicesDisabled:
                    reason = "Location Services disabled"
                case .permissionDenied:
                    reason = "Location permission denied"
                case .restricted:
                    reason = "Location restricted"
                case .timeout:
                    reason = "Location timed out"
                case .invalidCoordinates:
                    reason = "Invalid coordinates"
                }
            } else {
                reason = "Location unavailable"
            }
            subtitle = "Default location · \(reason)"
        }

        return try await fetchWeather(for: location, cityName: cityName, locationSubtitle: subtitle)
    }

    func fetchWeather(
        for location: CLLocation,
        cityName: String,
        locationSubtitle: String
    ) async throws -> Weather {
        guard locationService.isValidCoordinate(location.coordinate) else {
            throw WeatherServiceError.corruptedData("Invalid coordinates provided")
        }

        let cacheKey = cacheManager.cacheKey(
            for: cityName,
            coordinate: (lat: location.coordinate.latitude, lon: location.coordinate.longitude)
        )

        do {
            let spID = AppSignposts.shared.weatherSignposter.makeSignpostID()
            let spState = AppSignposts.shared.weatherSignposter.beginInterval("WeatherServiceNetworkCall", id: spID)
            let rawWeather = try await weatherService.weather(for: location)
            AppSignposts.shared.weatherSignposter.endInterval("WeatherServiceNetworkCall", spState)
            let mapped = WeatherKitMapper.mapToDomain(
                weather: rawWeather,
                cityName: cityName,
                locationSubtitle: locationSubtitle,
                coordinate: location.coordinate
            )
            cacheManager.save(weather: mapped, key: cacheKey)
            return mapped
        } catch {
            let mappedError = mapWeatherKitError(error)

            // If a valid cache exists, return it with isCached = true
            if let cached = cacheManager.load(key: cacheKey, allowExpired: true) {
                return cached.weather.asCached(isCached: true)
            }

            throw mappedError
        }
    }

    private func mapWeatherKitError(_ error: Error) -> WeatherServiceError {
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            if nsError.code == NSURLErrorTimedOut {
                return .timeout
            }
            if nsError.code == NSURLErrorNotConnectedToInternet || nsError.code == NSURLErrorNetworkConnectionLost {
                return .offline
            }
        }

        let desc = error.localizedDescription.lowercased()
        if desc.contains("unauthorized") || desc.contains("401") || desc.contains("403") {
            return .unauthorized
        }
        if desc.contains("rate limit") || desc.contains("429") {
            return .rateLimited
        }
        if desc.contains("timeout") {
            return .timeout
        }
        return .serverError(code: nsError.code)
    }
}
