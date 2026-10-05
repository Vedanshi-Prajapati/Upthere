import Foundation

public protocol GetWeatherUseCaseProtocol: Sendable {
    func execute() async throws -> Weather
}

public struct GetWeatherUseCase: GetWeatherUseCaseProtocol {
    private let repository: any WeatherRepository

    public init(repository: any WeatherRepository) {
        self.repository = repository
    }

    public func execute() async throws -> Weather {
        try await repository.fetchCurrentWeather()
    }
}
