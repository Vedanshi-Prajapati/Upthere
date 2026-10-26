import Foundation
import AppIntents
import CoreLocation

/// AppIntent allowing users and Siri to start tracking rain in a Live Activity
struct TrackRainIntent: AppIntent {
    static let title: LocalizedStringResource = "Track Rain"
    static let description = IntentDescription("Start a Live Activity to track upcoming or current rain in UpThere.")
    static let openAppWhenRun: Bool = false

    @Parameter(title: "Location", description: "City or location to track rain for")
    var location: LocationEntity?

    private var repository: (any WeatherRepository)?
    private var cacheManager: WeatherCacheManager?
    private var weatherLoader: (any IntentWeatherLoading)?

    init() {
        self.repository = nil
        self.cacheManager = nil
        self.weatherLoader = nil
    }

    init(
        location: LocationEntity?,
        repository: (any WeatherRepository)? = nil,
        cacheManager: WeatherCacheManager? = nil,
        weatherLoader: (any IntentWeatherLoading)? = nil
    ) {
        self.repository = repository
        self.cacheManager = cacheManager
        self.location = location
        self.weatherLoader = weatherLoader
    }

    static var parameterSummary: some ParameterSummary {
        Summary("Track rain in \(\.$location)")
    }

    @MainActor
    func perform() async throws -> some ReturnsValue<Bool> & ProvidesDialog {
        let loader = weatherLoader ?? IntentWeatherLoader()
        let (weather, resolved) = try await loader.loadWeather(
            for: location,
            repository: repository,
            cacheManager: cacheManager
        )

        let targetCity = resolved.cityName

        guard let rainWindow = InsightEngine().rainWindow(from: weather.hourlyForecast),
              RainActivityStateCalculator.isRainWithinTwoHours(rainWindow: rainWindow) else {
            return .result(
                value: false,
                dialog: IntentDialog(stringLiteral: IntentDialogSnippetBuilder.trackRainNoRainDialog(city: targetCity))
            )
        }

        let started = await RainActivityManager.shared.startRainActivity(
            city: targetCity,
            hourly: weather.hourlyForecast
        )

        if started {
            let calculation = RainActivityStateCalculator.calculateState(rainWindow: rainWindow)
            let dialogText = IntentDialogSnippetBuilder.trackRainStartedDialog(
                city: targetCity,
                minutesUntilRain: calculation?.minutesUntilRain ?? 0
            )
            return .result(value: true, dialog: IntentDialog(stringLiteral: dialogText))
        } else {
            return .result(
                value: false,
                dialog: IntentDialog(stringLiteral: IntentDialogSnippetBuilder.trackRainUnableToStartDialog())
            )
        }
    }
}
