import Foundation

@MainActor
public final class AppContainer {
    public let locationService: LocationService
    public let weatherRepository: any WeatherRepository
    public let getWeatherUseCase: any GetWeatherUseCaseProtocol

    public let settingsViewModel: SettingsViewModel

    public init(
        weatherRepository: (any WeatherRepository)? = nil,
        locationService: LocationService? = nil
    ) {
        let locService = locationService ?? .shared
        self.locationService = locService
        let repository = weatherRepository ?? WeatherKitWeatherRepository(locationService: locService)
        self.weatherRepository = repository
        self.getWeatherUseCase = GetWeatherUseCase(repository: repository)
        self.settingsViewModel = SettingsViewModel()
    }

    public func makeHomeViewModel() -> HomeViewModel {
        HomeViewModel(getWeatherUseCase: getWeatherUseCase)
    }
}
