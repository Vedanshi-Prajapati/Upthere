import Foundation

@MainActor
public final class AppContainer {
    public let weatherRepository: any WeatherRepository
    public let getWeatherUseCase: any GetWeatherUseCaseProtocol

    public init(weatherRepository: (any WeatherRepository)? = nil) {
        let repository = weatherRepository ?? MockWeatherRepository()
        self.weatherRepository = repository
        self.getWeatherUseCase = GetWeatherUseCase(repository: repository)
    }

    public func makeHomeViewModel() -> HomeViewModel {
        HomeViewModel(getWeatherUseCase: getWeatherUseCase)
        
    }
}
