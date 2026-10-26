import Foundation
import CoreLocation

protocol GetWeatherUseCaseProtocol: Sendable {
    func execute() async throws -> Weather
    func execute(for location: CLLocation, cityName: String, subtitle: String) async throws -> Weather
    func execute(for location: CLLocation, cityName: String, subtitle: String, locationStatus: LocationStatus) async throws -> Weather
}

extension GetWeatherUseCaseProtocol {
    func execute(for location: CLLocation, cityName: String, subtitle: String, locationStatus: LocationStatus) async throws -> Weather {
        try await execute(for: location, cityName: cityName, subtitle: subtitle)
    }
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

    func execute(for location: CLLocation, cityName: String, subtitle: String, locationStatus: LocationStatus) async throws -> Weather {
        try await repository.fetchWeather(for: location, cityName: cityName, locationSubtitle: subtitle, locationStatus: locationStatus)
    }
}
