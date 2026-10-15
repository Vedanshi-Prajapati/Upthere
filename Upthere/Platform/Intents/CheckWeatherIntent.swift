import Foundation
import AppIntents
import SwiftUI
import CoreLocation

/// AppIntent allowing users and Siri to check current weather conditions and forecast in UpThere
public struct CheckWeatherIntent: AppIntent {
    public static var title: LocalizedStringResource = "Check Weather"
    public static var description = IntentDescription("Check current weather conditions, temperature, and rain chances in UpThere.")
    public static var openAppWhenRun: Bool = false

    @Parameter(title: "Location", description: "City or location to check weather for")
    public var location: LocationEntity?

    public init() {}

    public init(location: LocationEntity?) {
        self.location = location
    }

    public static var parameterSummary: some ParameterSummary {
        Summary("Check weather in \(\.$location)")
    }

    @MainActor
    public func perform() async throws -> some ReturnsValue<String> & ProvidesDialog & ShowsSnippetView {
        let targetCity: String
        let coordinate: CLLocationCoordinate2D

        if let loc = location, loc.id != "current" {
            targetCity = loc.name
            coordinate = CLLocationCoordinate2D(latitude: loc.latitude, longitude: loc.longitude)
        } else {
            targetCity = LocationService.shared.currentCityName
            coordinate = LocationService.shared.currentLocation?.coordinate ?? LocationService.fallbackCoordinate.coordinate
        }

        // Fetch weather or fallback to cached/mock
        let weather: Weather
        do {
            let repo = WeatherKitWeatherRepository(locationService: LocationService.shared)
            weather = try await repo.fetchWeather(
                for: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude),
                cityName: targetCity,
                locationSubtitle: targetCity == LocationService.shared.currentCityName ? "Current Location" : ""
            )
        } catch {
            let cacheKey = WeatherCacheManager.shared.cacheKey(for: targetCity)
            weather = WeatherCacheManager.shared.load(key: cacheKey, allowExpired: true)?.weather ?? MockWeatherRepository.makeGhaziabadWeather()
        }

        let tempStr = "\(Int(round(weather.temperature)))°"
        let condition = weather.condition
        let rainChance = weather.chanceOfRain
        let highStr = "\(Int(round(weather.highTemperature)))°"
        let lowStr = "\(Int(round(weather.lowTemperature)))°"

        let dialogText = "It's currently \(tempStr) and \(condition) in \(weather.cityName), with a high of \(highStr), low of \(lowStr), and \(rainChance)% chance of rain."

        return .result(
            value: "\(weather.cityName): \(tempStr), \(condition)",
            dialog: IntentDialog(stringLiteral: dialogText),
            view: WeatherSnippetView(weather: weather)
        )
    }
}

// MARK: - Rich Siri / Shortcuts Snippet Card
private struct WeatherSnippetView: View {
    let weather: Weather

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.14, green: 0.38, blue: 0.78),
                    Color(red: 0.04, green: 0.16, blue: 0.44)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(weather.cityName)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.white)
                        Text(weather.condition)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.8))
                    }
                    Spacer()
                    Image(systemName: weather.weatherSymbolName)
                        .symbolRenderingMode(.multicolor)
                        .symbolVariant(.fill)
                        .foregroundStyle(.white)
                        .font(.system(size: 32))
                }

                HStack(alignment: .firstTextBaseline) {
                    Text(WeatherFormatter.shared.temp(weather.temperature))
                        .font(.system(size: 44, weight: .thin, design: .rounded))
                        .foregroundStyle(.white)

                    Spacer()

                    VStack(alignment: .trailing, spacing: 3) {
                        Text("H \(WeatherFormatter.shared.temp(weather.highTemperature))  L \(WeatherFormatter.shared.temp(weather.lowTemperature))")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.85))

                        let rainChance = weather.chanceOfRain
                        if rainChance > 0 {
                            HStack(spacing: 3) {
                                Image(systemName: "umbrella.fill")
                                    .font(.system(size: 11))
                                Text("\(rainChance)%")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .foregroundStyle(Color(red: 0.55, green: 0.85, blue: 1.0))
                        }
                    }
                }
            }
            .padding(16)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .padding(8)
    }
}
