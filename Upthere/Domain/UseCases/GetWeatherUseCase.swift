import Foundation
import CoreLocation

protocol GetWeatherUseCaseProtocol: Sendable {
    func execute() async throws -> Weather
    func execute(for location: CLLocation, cityName: String, subtitle: String) async throws -> Weather
}

struct GetWeatherUseCase: GetWeatherUseCaseProtocol {
    private let repository: any WeatherRepository

    init(repository: any WeatherRepository) {
        self.repository = repository
    }

    func execute() async throws -> Weather {
        try await repository.fetchCurrentWeather()
    }

    func execute(for location: CLLocation, cityName: String, subtitle: String) async throws -> Weather {
        try await repository.fetchWeather(for: location, cityName: cityName, locationSubtitle: subtitle)
    }
}
