import Foundation
import CoreLocation

public protocol GetWeatherUseCaseProtocol: Sendable {
    func execute() async throws -> Weather
    func execute(for location: CLLocation, cityName: String, subtitle: String) async throws -> Weather
}

public struct GetWeatherUseCase: GetWeatherUseCaseProtocol {
    private let repository: any WeatherRepository

    public init(repository: any WeatherRepository) {
        self.repository = repository
    }

    public func execute() async throws -> Weather {
        try await repository.fetchCurrentWeather()
    }

    public func execute(for location: CLLocation, cityName: String, subtitle: String) async throws -> Weather {
        try await repository.fetchWeather(for: location, cityName: cityName, locationSubtitle: subtitle)
    }
}
