import Foundation
import CoreLocation

public protocol WeatherRepository: Sendable {
    func fetchCurrentWeather() async throws -> Weather
    func fetchWeather(for location: CLLocation, cityName: String, locationSubtitle: String) async throws -> Weather
}
