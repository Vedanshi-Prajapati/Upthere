import Foundation
import SwiftUI
import AppIntents

/// Shared builder for dialog strings and snippet views across AppIntents.
enum IntentDialogSnippetBuilder {
    // MARK: - Check Weather Intent

    static func checkWeatherSummaryValue(for weather: Weather) -> String {
        let tempStr = "\(Int(round(weather.temperature)))°"
        return "\(weather.cityName): \(tempStr), \(weather.condition)"
    }

    static func checkWeatherDialogText(for weather: Weather) -> String {
        let tempStr = "\(Int(round(weather.temperature)))°"
        let condition = weather.condition
        let rainChance = weather.chanceOfRain
        let highStr = "\(Int(round(weather.highTemperature)))°"
        let lowStr = "\(Int(round(weather.lowTemperature)))°"

        return "It's currently \(tempStr) and \(condition) in \(weather.cityName), with a high of \(highStr), low of \(lowStr), and \(rainChance)% chance of rain."
    }

    static func makeWeatherSnippetView(for weather: Weather) -> some View {
        WeatherSnippetView(weather: weather)
    }

    // MARK: - Track Rain Intent

    static func trackRainNoRainDialog(city: String) -> String {
        "No rain expected within the next 2 hours in \(city)."
    }

    static func trackRainStartedDialog(city: String, minutesUntilRain: Int) -> String {
        if minutesUntilRain > 0 {
            return "Tracking rain for \(city). Rain starting in \(minutesUntilRain) minutes."
        } else {
            return "Tracking rain for \(city). Rain is currently in progress."
        }
    }

    static func trackRainUnableToStartDialog() -> String {
        "Unable to start rain tracking. Please ensure Live Activities are enabled in Settings."
    }
}

// MARK: - Rich Siri / Shortcuts Snippet Card
struct WeatherSnippetView: View {
    @Environment(\.weatherFormatter) private var weatherFormatter
    let weather: Weather

    init(weather: Weather) {
        self.weather = weather
    }

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
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.white)
                        Text(weather.condition)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color.white.opacity(0.8))
                    }
                    Spacer()
                    Image(systemName: weather.weatherSymbolName)
                        .symbolRenderingMode(.multicolor)
                        .symbolVariant(.fill)
                        .foregroundStyle(.white)
                        .font(.largeTitle)
                }

                HStack(alignment: .firstTextBaseline) {
                    Text(weatherFormatter.temp(weather.temperature))
                        .font(.largeTitle.weight(.thin))
                        .foregroundStyle(.white)

                    Spacer()

                    VStack(alignment: .trailing, spacing: 3) {
                        Text("H \(weatherFormatter.temp(weather.highTemperature))  L \(weatherFormatter.temp(weather.lowTemperature))")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Color.white.opacity(0.85))

                        let rainChance = weather.chanceOfRain
                        if rainChance > 0 {
                            HStack(spacing: 3) {
                                Image(systemName: "umbrella.fill")
                                    .font(.caption2)
                                Text(verbatim: (Double(rainChance) / 100.0).formatted(.percent))
                                    .font(.caption.weight(.semibold))
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
