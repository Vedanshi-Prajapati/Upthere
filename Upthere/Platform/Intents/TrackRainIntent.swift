import Foundation
import AppIntents
import CoreLocation

/// AppIntent allowing users and Siri to start tracking rain in a Live Activity
public struct TrackRainIntent: AppIntent {
    public static let title: LocalizedStringResource = "Track Rain"
    public static let description = IntentDescription("Start a Live Activity to track upcoming or current rain in UpThere.")
    public static let openAppWhenRun: Bool = false

    @Parameter(title: "Location", description: "City or location to track rain for")
    public var location: LocationEntity?

    private var repository: (any WeatherRepository)?
    private var cacheManager: WeatherCacheManager?

    public init() {
        self.repository = nil
        self.cacheManager = nil
    }

    public init(
        location: LocationEntity?,
        repository: (any WeatherRepository)? = nil,
        cacheManager: WeatherCacheManager? = nil
    ) {
        self.repository = repository
        self.cacheManager = cacheManager
        self.location = location
    }

    public static var parameterSummary: some ParameterSummary {
        Summary("Track rain in \(\.$location)")
    }

    @MainActor
    public func perform() async throws -> some ReturnsValue<Bool> & ProvidesDialog {
        let targetCity: String
        let coordinate: CLLocationCoordinate2D

        if let loc = location, loc.id != "current" {
            targetCity = loc.name
            coordinate = CLLocationCoordinate2D(latitude: loc.latitude, longitude: loc.longitude)
        } else {
            targetCity = LocationService.shared.currentCityName
            coordinate = LocationService.shared.currentLocation?.coordinate ?? LocationService.fallbackCoordinate.coordinate
        }

        // Fetch current weather or fallback to cached
        let cache = cacheManager ?? WeatherCacheManager.shared
        let repo = repository ?? WeatherKitWeatherRepository(locationService: LocationService.shared, cacheManager: cache)

        let weather: Weather
        do {
            weather = try await repo.fetchWeather(
                for: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude),
                cityName: targetCity,
                locationSubtitle: targetCity == LocationService.shared.currentCityName ? "Current Location" : ""
            )
        } catch {
            let coordKey = cache.cacheKey(
                for: targetCity,
                coordinate: (lat: coordinate.latitude, lon: coordinate.longitude)
            )
            let cityKey = cache.cacheKey(for: targetCity)
            if let cached = cache.load(key: coordKey, allowExpired: true)?.weather ?? cache.load(key: cityKey, allowExpired: true)?.weather {
                weather = cached
            } else {
                throw WeatherUnavailableError()
            }
        }

        guard let rainWindow = InsightEngine().rainWindow(from: weather.hourlyForecast),
              RainActivityStateCalculator.isRainWithinTwoHours(rainWindow: rainWindow) else {
            return .result(
                value: false,
                dialog: IntentDialog("No rain expected within the next 2 hours in \(targetCity).")
            )
        }

        let started = await RainActivityManager.shared.startRainActivity(
            city: targetCity,
            hourly: weather.hourlyForecast
        )

        if started {
            let calculation = RainActivityStateCalculator.calculateState(rainWindow: rainWindow)
            let dialogText: String
            if let calc = calculation, calc.minutesUntilRain > 0 {
                dialogText = "Tracking rain for \(targetCity). Rain starting in \(calc.minutesUntilRain) minutes."
            } else {
                dialogText = "Tracking rain for \(targetCity). Rain is currently in progress."
            }
            return .result(value: true, dialog: IntentDialog(stringLiteral: dialogText))
        } else {
            return .result(
                value: false,
                dialog: IntentDialog("Unable to start rain tracking. Please ensure Live Activities are enabled in Settings.")
            )
        }
    }
}
