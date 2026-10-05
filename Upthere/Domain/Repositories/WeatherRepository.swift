import Foundation

public protocol WeatherRepository: Sendable {
    func fetchCurrentWeather() async throws -> Weather
}
