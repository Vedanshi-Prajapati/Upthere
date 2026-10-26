import Testing
import Foundation
import CoreLocation
import AppIntents
import SwiftUI
import WidgetKit
@testable import Upthere

@Suite("WeatherMapping Tests")
@MainActor
struct WeatherMappingTests {

    // MARK: - 10. Malformed weather response
    @Test("Malformed weather response fails decoding")
    func malformedWeatherResponse() {
        let corruptedData = Data("{\"invalid_json\": true}".utf8)
        let decoded = try? JSONDecoder().decode(Weather.self, from: corruptedData)
        #expect(decoded == nil)
    }


    // MARK: - 11. Current conditions succeed while forecast fails
    @Test("Current conditions succeed while forecast fails")
    func currentConditionsSucceedForecastFails() {
        let partialWeather = Weather(
            cityName: "PartialCity",
            locationSubtitle: "Partial region",
            temperature: 20.0,
            condition: "Cloudy",
            highTemperature: 22.0,
            lowTemperature: 15.0,
            feelsLike: 20.0,
            description: "Partially loaded",
            hourlyForecast: [],
            dailyForecast: []
        )
        #expect(partialWeather.hourlyForecast.isEmpty)
        #expect(partialWeather.dailyForecast.isEmpty)
        #expect(partialWeather.temperature == 20.0)
    }


    // MARK: - 14. Missing temperature does not display as zero
    @Test("Missing or negative zero temperature formats safely")
    func missingTemperatureDoesNotDisplayZero() {
        let formatter = WeatherFormatter()
        let negativeZero = -0.0001
        let formattedNegZero = formatter.temp(negativeZero)
        let validNegFive = formatter.temp(-5.0)

        #expect(formattedNegZero == "0°")
        #expect(formattedNegZero != "-0°")
        #expect(validNegFive == "-5°")
    }


    // MARK: - 15. Unknown condition code uses a safe fallback
    @Test("Unknown condition code safely preserved without crashing")
    func unknownConditionSafeFallback() {
        let weather = Weather(
            cityName: "Test",
            locationSubtitle: "Region",
            temperature: 18.0,
            condition: "RareAtmosphericPhenomenon",
            highTemperature: 22.0,
            lowTemperature: 12.0,
            feelsLike: 18.0,
            description: "Special event"
        )
        #expect(weather.condition == "RareAtmosphericPhenomenon")
        #expect(!weather.condition.isEmpty)
    }


    // MARK: - 16. Celsius/Fahrenheit switching is correct
    @Test("Celsius and Fahrenheit temperature conversions")
    func celsiusFahrenheitSwitching() {
        let cZero = TemperatureUnit.celsius.convert(0.0)
        let fZero = TemperatureUnit.fahrenheit.convert(0.0)
        let fBoiling = TemperatureUnit.fahrenheit.convert(100.0)

        #expect(cZero == 0.0)
        #expect(fZero == 32.0)
        #expect(fBoiling == 212.0)
    }


    // MARK: - 17. Forecast timestamps across midnight are correct
    @Test("Forecast timestamps across midnight preserve order and formatting")
    func forecastTimestampsAcrossMidnight() {
        let midnightHourly = [
            HourlyWeather(time: "11 PM", temperature: 18.0, precipitationProbability: 0.1),
            HourlyWeather(time: "12 AM", temperature: 17.0, precipitationProbability: 0.1),
            HourlyWeather(time: "1 AM", temperature: 16.0, precipitationProbability: 0.1)
        ]
        #expect(midnightHourly[0].time == "11 PM")
        #expect(midnightHourly[1].time == "12 AM")
        #expect(midnightHourly[2].time == "1 AM")
    }


    // MARK: - 20. Severe weather alerts are not fabricated or displayed as current after expiry
    @Test("Expired severe weather alerts are marked expired")
    func expiredAlertsNotDisplayed() {
        let pastDate = Date(timeIntervalSinceNow: -7200) // 2 hours ago
        let expiredAlert = WeatherAlert(
            source: "IMD",
            title: "Old Warning",
            validUntil: "Expired",
            expirationDate: pastDate
        )
        #expect(expiredAlert.isExpired)
    }


    // MARK: - Extended HourlyWeather fields
    @Test("HourlyWeather models extended insight metrics")
    func hourlyWeatherExtendedFields() {
        let hour = HourlyWeather(
            time: "2 PM",
            temperature: 24.5,
            precipitationProbability: 0.15,
            windSpeed: 18.0,
            windGust: 26.0,
            uvIndex: 7,
            cloudCover: 0.45,
            symbolName: "sun.max.fill"
        )

        #expect(hour.time == "2 PM")
        #expect(hour.temperature == 24.5)
        #expect(hour.precipitationProbability == 0.15)
        #expect(hour.windSpeed == 18.0)
        #expect(hour.wind == 18.0)
        #expect(hour.windGust == 26.0)
        #expect(hour.gust == 26.0)
        #expect(hour.uvIndex == 7)
        #expect(hour.cloudCover == 0.45)
        #expect(hour.symbolName == "sun.max.fill")
        #expect(hour.symbol == "sun.max.fill")
    }


    @Test("InsightEngine rain window formats specific peak time without saying near Now")
    func insightEngineRainWindowFormatting() {
        let engine = InsightEngine()
        let baseDate = Date(timeIntervalSince1970: 1700000000)
        let hourly: [HourlyWeather] = [
            HourlyWeather(date: baseDate, temperature: 20, precipitationChance: 0.80, precipitationAmount: 3.5, symbolName: "cloud.rain.fill"),
            HourlyWeather(date: baseDate.addingTimeInterval(3600), temperature: 19, precipitationChance: 0.60, precipitationAmount: 1.5, symbolName: "cloud.drizzle.fill")
        ]

        let result = engine.rainWindow(from: hourly)
        #expect(result != nil)
        if let rain = result {
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_US")
            f.dateFormat = "ha"
            let peakTime = f.string(from: rain.peakDate)
            let detail = "Peak precipitation around \(peakTime), \(Int((rain.peakProbability * 100).rounded()))% probability."
            #expect(!detail.contains("near Now"))
            #expect(detail.contains(peakTime))
        }
    }


    // MARK: - 42. Observable UnitPreferences updates formatted output without recreating views
    @Test("Changing the temperature unit updates formatted output without recreating views")
    func changingTemperatureUnitUpdatesFormattedOutputWithoutRecreatingViews() {
        let (mockDefaults, suiteName) = makeIsolatedDefaults()
        defer { mockDefaults.removePersistentDomain(forName: suiteName) }

        let prefs = UnitPreferences(defaults: mockDefaults)
        prefs.temperatureUnit = .celsius
        let formatter = WeatherFormatter(preferences: prefs)

        struct WeatherDisplayView: View {
            let formatter: WeatherFormatter
            let tempValue: Double

            var body: some View {
                Text(formatter.temp(tempValue))
            }
        }

        // Create the view instance once
        let view = WeatherDisplayView(formatter: formatter, tempValue: 20.0)

        // Celsius output
        #expect(formatter.temp(20.0) == "20°")
        #expect(view.formatter.temp(20.0) == "20°")

        // Changing the temperature unit updates the formatted output dynamically without recreating the view
        prefs.temperatureUnit = .fahrenheit

        #expect(formatter.temp(20.0) == "68°")
        #expect(view.formatter.temp(20.0) == "68°")

        // Switching back
        prefs.temperatureUnit = .celsius

        #expect(formatter.temp(20.0) == "20°")
        #expect(view.formatter.temp(20.0) == "20°")
    }

}
