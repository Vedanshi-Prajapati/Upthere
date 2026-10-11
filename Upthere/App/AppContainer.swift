import Foundation

@MainActor
public final class AppContainer {
    public let locationService: LocationService
    public let weatherRepository: any WeatherRepository
    public let getWeatherUseCase: any GetWeatherUseCaseProtocol

    public init(
        weatherRepository: (any WeatherRepository)? = nil,
        locationService: LocationService? = nil
    ) {
        let locService = locationService ?? .shared
        self.locationService = locService
        let repository = weatherRepository ?? WeatherKitWeatherRepository(locationService: locService)
        self.weatherRepository = repository
        self.getWeatherUseCase = GetWeatherUseCase(repository: repository)
    }

    public func makeHomeViewModel() -> HomeViewModel {
        HomeViewModel(getWeatherUseCase: getWeatherUseCase)
    }
}
