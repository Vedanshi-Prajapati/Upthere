import Foundation
import CoreLocation

protocol WeatherRepository: Sendable {
    func fetchCurrentWeather() async throws -> Weather
    func fetchWeather(for location: CLLocation, cityName: String, locationSubtitle: String) async throws -> Weather
    func fetchWeather(for location: CLLocation, cityName: String, locationSubtitle: String, locationStatus: LocationStatus) async throws -> Weather
}

extension WeatherRepository {
    func fetchWeather(for location: CLLocation, cityName: String, locationSubtitle: String, locationStatus: LocationStatus) async throws -> Weather {
        try await fetchWeather(for: location, cityName: cityName, locationSubtitle: locationSubtitle)
    }
}
