import Foundation
import CoreLocation

public enum MockWeatherError: LocalizedError {
    case simulatedFailure
    public var errorDescription: String? { "Failed to load weather data (simulated error)." }
}

public final class MockWeatherRepository: WeatherRepository {
    private let mockWeather: Weather?
    private let shouldFail: Bool

    public init(mockWeather: Weather? = nil, shouldFail: Bool = false) {
        self.mockWeather = mockWeather
        self.shouldFail = shouldFail
    }

    public func fetchCurrentWeather() async throws -> Weather {
        try await Task.sleep(nanoseconds: 300_000_000)
        if shouldFail { throw MockWeatherError.simulatedFailure }
        return mockWeather ?? Self.makeGhaziabadWeather()
    }

    public func fetchWeather(
        for location: CLLocation,
        cityName: String,
        locationSubtitle: String
    ) async throws -> Weather {
        try await Task.sleep(nanoseconds: 300_000_000)
        if shouldFail { throw MockWeatherError.simulatedFailure }
        let base = mockWeather ?? Self.makeGhaziabadWeather()
        return Weather(
            cityName: cityName,
            locationSubtitle: locationSubtitle.isEmpty ? base.locationSubtitle : locationSubtitle,
            temperature: base.temperature,
            condition: base.condition,
            highTemperature: base.highTemperature,
            lowTemperature: base.lowTemperature,
            feelsLike: base.feelsLike,
            weatherSymbolName: base.weatherSymbolName,
            description: base.description,
            humidity: base.humidity,
            dewPoint: base.dewPoint,
            windSpeed: base.windSpeed,
            windDirection: base.windDirection,
            precipitationChance: base.precipitationChance,
            uvIndex: base.uvIndex,
            uvDescription: base.uvDescription,
            visibility: base.visibility,
            visibilityDescription: base.visibilityDescription,
            pressure: base.pressure,
            pressureTrend: base.pressureTrend,
            alert: base.alert,
            hourlyForecast: base.hourlyForecast,
            dailyForecast: base.dailyForecast,
            rainWindow: base.rainWindow,
            warmingInsight: base.warmingInsight,
            chanceOfRain: base.chanceOfRain,
            sunrise: base.sunrise,
            sunset: base.sunset
        )
    }

    public static func makeGhaziabadWeather() -> Weather {
        let hourly: [HourlyWeather] = [
            .init(time: "Now",  temperature: 28, precipitationProbability: 0.05),
            .init(time: "9a",   temperature: 29, precipitationProbability: 0.05),
            .init(time: "10a",  temperature: 31, precipitationProbability: 0.07),
            .init(time: "11a",  temperature: 32, precipitationProbability: 0.10),
            .init(time: "12p",  temperature: 33, precipitationProbability: 0.15),
            .init(time: "1p",   temperature: 35, precipitationProbability: 0.20),
            .init(time: "2p",   temperature: 34, precipitationProbability: 0.30),
            .init(time: "3p",   temperature: 33, precipitationProbability: 0.42),
            .init(time: "4p",   temperature: 31, precipitationProbability: 0.65),
            .init(time: "5p",   temperature: 30, precipitationProbability: 0.70),
            .init(time: "6p",   temperature: 29, precipitationProbability: 0.60),
            .init(time: "7p",   temperature: 28, precipitationProbability: 0.38),
            .init(time: "8p",   temperature: 28, precipitationProbability: 0.18),
            .init(time: "9p",   temperature: 27, precipitationProbability: 0.12),
            .init(time: "10p",  temperature: 27, precipitationProbability: 0.08),
            .init(time: "11p",  temperature: 26, precipitationProbability: 0.05),
        ]

        let daily: [DailyWeather] = [
            .init(dayName: "Today", date: "6 Oct", symbolName: "cloud.bolt.rain.fill", precipitationProbability: 0.70, lowTemperature: 25, highTemperature: 35),
            .init(dayName: "Wed", date: "7 Oct", symbolName: "cloud.sun.fill", lowTemperature: 24, highTemperature: 34),
            .init(dayName: "Thu", date: "8 Oct", symbolName: "sun.max.fill", lowTemperature: 23, highTemperature: 33),
            .init(dayName: "Fri", date: "9 Oct", symbolName: "sun.max.fill", lowTemperature: 23, highTemperature: 34),
            .init(dayName: "Sat", date: "10 Oct", symbolName: "cloud.sun.fill", lowTemperature: 24, highTemperature: 33),
            .init(dayName: "Sun", date: "11 Oct", symbolName: "cloud.fill", precipitationProbability: 0.30, lowTemperature: 24, highTemperature: 31),
            .init(dayName: "Mon", date: "12 Oct", symbolName: "cloud.rain.fill", precipitationProbability: 0.65, lowTemperature: 23, highTemperature: 29),
            .init(dayName: "Tue", date: "13 Oct", symbolName: "cloud.sun.rain.fill", precipitationProbability: 0.20, lowTemperature: 22, highTemperature: 31),
            .init(dayName: "Wed", date: "14 Oct", symbolName: "cloud.sun.fill", lowTemperature: 22, highTemperature: 32),
            .init(dayName: "Thu", date: "15 Oct", symbolName: "sun.max.fill", lowTemperature: 23, highTemperature: 33)
        ]

        return Weather(
            cityName: "Ghaziabad",
            locationSubtitle: "Current location · Tue 6 Oct, 8:00 AM",
            temperature: 28,
            condition: "Partly Cloudy",
            highTemperature: 35,
            lowTemperature: 25,
            feelsLike: 30,
            weatherSymbolName: "cloud.sun.fill",
            description: "Hazy sunshine this morning, turning humid. Thunderstorms possible from 4 PM.",
            humidity: 51,
            dewPoint: 22,
            windSpeed: 10,
            windDirection: "From northwest",
            precipitationChance: 5,
            uvIndex: 2,
            uvDescription: "Low",
            visibility: 6,
            visibilityDescription: "Haze",
            pressure: 1006,
            pressureTrend: "Falling",
            alert: WeatherAlert(
                source: "IMD",
                title: "Yellow Alert · Thunderstorm",
                validUntil: "Until 9:00 PM"
            ),
            hourlyForecast: hourly,
            dailyForecast: daily,
            rainWindow: RainWindow(
                title: "Rain likely later",
                timeRange: "4:00 PM – 6:30 PM",
                detail: "Most likely near 5 PM, at 70% probability."
            ),
            warmingInsight: "+7° warming from 8 AM to 1 PM",
            chanceOfRain: 70,
            sunrise: "6:12 AM",
            sunset: "5:51 PM"
        )
    }
}
