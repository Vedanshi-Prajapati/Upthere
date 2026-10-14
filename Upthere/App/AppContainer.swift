import Foundation

@MainActor
public final class AppContainer {
    public let locationService: LocationService
    public let weatherRepository: any WeatherRepository
    public let getWeatherUseCase: any GetWeatherUseCaseProtocol

    public let settingsViewModel: SettingsViewModel
    public let homeViewModel: HomeViewModel

    public init(
        weatherRepository: (any WeatherRepository)? = nil,
        locationService: LocationService? = nil
    ) {
        let locService = locationService ?? LocationService()
        self.locationService = locService
        let repository = weatherRepository ?? WeatherKitWeatherRepository(locationService: locService)
        self.weatherRepository = repository
        let useCase = GetWeatherUseCase(repository: repository)
        self.getWeatherUseCase = useCase
        self.settingsViewModel = SettingsViewModel(locationService: locService)
        self.homeViewModel = HomeViewModel(
            getWeatherUseCase: useCase,
            locationService: locService
        )
    }

    public func makeHomeViewModel() -> HomeViewModel {
        homeViewModel
    }
}
