import Foundation
#if canImport(UIKit)
import UIKit
#endif

@MainActor
final class AppContainer {
    let unitPreferences: UnitPreferences
    let weatherFormatter: WeatherFormatter
    let locationService: LocationService
    let locationsManager: SavedLocationsManager
    let weatherRepository: any WeatherRepository
    let getWeatherUseCase: any GetWeatherUseCaseProtocol

    let settingsViewModel: SettingsViewModel
    let homeViewModel: HomeViewModel

    init(
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
        #if DEBUG
        let isTesting = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        if isTesting || ProcessInfo.processInfo.arguments.contains("-useMockRepository") {
            if let condIdx = ProcessInfo.processInfo.arguments.firstIndex(of: "-mockCondition"),
               condIdx + 1 < ProcessInfo.processInfo.arguments.count {
                let condName = ProcessInfo.processInfo.arguments[condIdx + 1]
                let (condition, symbol): (String, String) = {
                    switch condName.lowercased() {
                    case "clear", "sunny", "clearday":
                        return ("Sunny", "sun.max.fill")
                    case "partlycloudy":
                        return ("Partly Cloudy", "cloud.sun.fill")
                    case "rain", "rainy":
                        return ("Heavy Rain", "cloud.rain.fill")
                    case "snow", "snowy":
                        return ("Brisk Snow", "snowflake")
                    case "fog", "cloudy", "overcast":
                        return ("Dense Fog", "cloud.fog.fill")
                    case "night":
                        return ("Clear Night", "moon.stars.fill")
                    default:
                        return (condName, "cloud.sun.fill")
                    }
                }()
                repository = MockWeatherRepository(
                    mockWeather: MockWeatherRepository.makeWeather(condition: condition, symbolName: symbol),
                    delayNanoseconds: 0
                )
            } else {
                repository = MockWeatherRepository(delayNanoseconds: 0)
            }
        } else {
            repository = weatherRepository ?? WeatherKitWeatherRepository(locationService: locService)
        }
        #else
        repository = weatherRepository ?? WeatherKitWeatherRepository(locationService: locService)
        #endif
        self.weatherRepository = repository
        let useCase = GetWeatherUseCase(repository: repository)
        self.getWeatherUseCase = useCase
        let scheduler = notificationScheduler ?? NotificationScheduler.shared

        self.settingsViewModel = SettingsViewModel(
            unitPreferences: prefs,
            locationService: locService,
            notificationScheduler: scheduler
        )
        let widgetWriter = WidgetSnapshotStore.shared
        let spotlightIndexer = SpotlightService.shared
        let rainUpdater = RainActivityManager.shared
        let metrics = AppSignposts.shared
        let coordinator = WeatherRefreshCoordinator(
            widgetSnapshotWriter: widgetWriter,
            spotlightIndexer: spotlightIndexer,
            rainActivityUpdater: rainUpdater,
            notificationScheduler: scheduler,
            fetchMetrics: metrics,
            defaults: AppGroup.defaults
        )

        self.homeViewModel = HomeViewModel(
            getWeatherUseCase: useCase,
            refreshCoordinator: coordinator,
            cacheManager: WeatherCacheManager.shared,
            locationsManager: locManager,
            locationService: locService,
            defaults: AppGroup.defaults,
            openSettingsAction: {
                #if canImport(UIKit)
                if let url = URL(string: UIApplication.openSettingsURLString),
                   UIApplication.shared.canOpenURL(url) {
                    UIApplication.shared.open(url)
                }
                #endif
            }
        )
    }

    func makeHomeViewModel() -> HomeViewModel {
        homeViewModel
    }
}
