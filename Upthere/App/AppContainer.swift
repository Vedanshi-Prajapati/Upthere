import Foundation

@MainActor
public final class AppContainer {
    public let unitPreferences: UnitPreferences
    public let weatherFormatter: WeatherFormatter
    public let locationService: LocationService
    public let locationsManager: SavedLocationsManager
    public let weatherRepository: any WeatherRepository
    public let getWeatherUseCase: any GetWeatherUseCaseProtocol

    public let settingsViewModel: SettingsViewModel
    public let homeViewModel: HomeViewModel

    public init(
        unitPreferences: UnitPreferences? = nil,
        weatherRepository: (any WeatherRepository)? = nil,
        locationService: LocationService? = nil,
        locationsManager: SavedLocationsManager? = nil,
        notificationScheduler: (any NotificationSchedulerProtocol)? = nil
    ) {
        let prefs = unitPreferences ?? UnitPreferences()
        self.unitPreferences = prefs
        self.weatherFormatter = WeatherFormatter(preferences: prefs)

        let locService = locationService ?? LocationService()
        self.locationService = locService

        let locManager = locationsManager ?? SavedLocationsManager()
        self.locationsManager = locManager

        let repository: any WeatherRepository
        if ProcessInfo.processInfo.arguments.contains("-useMockRepository") {
            repository = MockWeatherRepository()
        } else {
            repository = weatherRepository ?? WeatherKitWeatherRepository(locationService: locService)
        }
        self.weatherRepository = repository
        let useCase = GetWeatherUseCase(repository: repository)
        self.getWeatherUseCase = useCase
        let scheduler = notificationScheduler ?? NotificationScheduler.shared

        self.settingsViewModel = SettingsViewModel(
            unitPreferences: prefs,
            locationService: locService,
            notificationScheduler: scheduler
        )
        self.homeViewModel = HomeViewModel(
            getWeatherUseCase: useCase,
            locationsManager: locManager,
            locationService: locService,
            notificationScheduler: scheduler
        )
    }

    public func makeHomeViewModel() -> HomeViewModel {
        homeViewModel
    }
}
