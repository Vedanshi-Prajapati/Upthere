import Foundation
import AppIntents
import SwiftUI
import CoreLocation

/// AppIntent allowing users and Siri to check current weather conditions and forecast in UpThere
struct CheckWeatherIntent: AppIntent {
    static let title: LocalizedStringResource = "Check Weather"
    static let description = IntentDescription("Check current weather conditions, temperature, and rain chances in UpThere.")
    static let openAppWhenRun: Bool = false

    @Parameter(title: "Location", description: "City or location to check weather for")
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
        Summary("Check weather in \(\.$location)")
    }

    @MainActor
    func perform() async throws -> some ReturnsValue<String> & ProvidesDialog & ShowsSnippetView {
        let loader = weatherLoader ?? IntentWeatherLoader()
        let (weather, _) = try await loader.loadWeather(
            for: location,
            repository: repository,
            cacheManager: cacheManager
        )

        let summaryValue = IntentDialogSnippetBuilder.checkWeatherSummaryValue(for: weather)
        let dialogText = IntentDialogSnippetBuilder.checkWeatherDialogText(for: weather)

        return .result(
            value: summaryValue,
            dialog: IntentDialog(stringLiteral: dialogText),
            view: IntentDialogSnippetBuilder.makeWeatherSnippetView(for: weather)
        )
    }
}
