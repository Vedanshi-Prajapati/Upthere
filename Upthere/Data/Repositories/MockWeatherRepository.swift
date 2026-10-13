import Foundation
import CoreLocation

public final class MockWeatherRepository: WeatherRepository, @unchecked Sendable {
    public var mockWeather: Weather?
    public var errorToThrow: Error?
    public var delayNanoseconds: UInt64
    public private(set) var fetchCallCount: Int = 0

    public init(
        mockWeather: Weather? = nil,
        shouldFail: Bool = false,
        errorToThrow: Error? = nil,
        delayNanoseconds: UInt64 = 50_000_000
    ) {
        self.mockWeather = mockWeather
        self.delayNanoseconds = delayNanoseconds
        if let error = errorToThrow {
            self.errorToThrow = error
        } else if shouldFail {
            self.errorToThrow = WeatherServiceError.serverError(code: 500)
        } else {
            self.errorToThrow = nil
        }
    }

    public func fetchCurrentWeather() async throws -> Weather {
        fetchCallCount += 1
        if delayNanoseconds > 0 {
            try? await Task.sleep(nanoseconds: delayNanoseconds)
        }
        if let err = errorToThrow {
            throw err
        }
        return mockWeather ?? Self.makeGhaziabadWeather()
    }

    public func fetchWeather(
        for location: CLLocation,
        cityName: String,
        locationSubtitle: String
    ) async throws -> Weather {
        fetchCallCount += 1
        if delayNanoseconds > 0 {
            try? await Task.sleep(nanoseconds: delayNanoseconds)
        }
        if let err = errorToThrow {
            throw err
        }
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
            sunset: base.sunset,
            fetchTimestamp: base.fetchTimestamp,
            isCached: base.isCached
        )
    }

    public static func makeGhaziabadWeather() -> Weather {
        let hourly: [HourlyWeather] = [
            .init(time: "Now",  temperature: 28, precipitationProbability: 0.05, windSpeed: 10, windGust: 14, uvIndex: 3, cloudCover: 0.30, symbolName: "cloud.sun.fill"),
            .init(time: "9a",   temperature: 29, precipitationProbability: 0.05, windSpeed: 11, windGust: 15, uvIndex: 5, cloudCover: 0.35, symbolName: "sun.max.fill"),
            .init(time: "10a",  temperature: 31, precipitationProbability: 0.07, windSpeed: 13, windGust: 17, uvIndex: 7, cloudCover: 0.40, symbolName: "sun.max.fill"),
            .init(time: "11a",  temperature: 32, precipitationProbability: 0.10, windSpeed: 14, windGust: 18, uvIndex: 9, cloudCover: 0.45, symbolName: "cloud.sun.fill"),
            .init(time: "12p",  temperature: 33, precipitationProbability: 0.15, windSpeed: 16, windGust: 22, uvIndex: 11, cloudCover: 0.50, symbolName: "cloud.sun.fill"),
            .init(time: "1p",   temperature: 35, precipitationProbability: 0.20, windSpeed: 18, windGust: 25, uvIndex: 10, cloudCover: 0.60, symbolName: "cloud.fill"),
            .init(time: "2p",   temperature: 34, precipitationProbability: 0.30, windSpeed: 20, windGust: 28, uvIndex: 8, cloudCover: 0.70, symbolName: "cloud.fill"),
            .init(time: "3p",   temperature: 33, precipitationProbability: 0.42, windSpeed: 22, windGust: 30, uvIndex: 5, cloudCover: 0.85, symbolName: "cloud.bolt.rain.fill"),
            .init(time: "4p",   temperature: 31, precipitationProbability: 0.65, windSpeed: 25, windGust: 35, uvIndex: 2, cloudCover: 0.95, symbolName: "cloud.rain.fill"),
            .init(time: "5p",   temperature: 30, precipitationProbability: 0.70, windSpeed: 24, windGust: 34, uvIndex: 1, cloudCover: 0.95, symbolName: "cloud.rain.fill"),
            .init(time: "6p",   temperature: 29, precipitationProbability: 0.60, windSpeed: 20, windGust: 28, uvIndex: 0, cloudCover: 0.90, symbolName: "cloud.rain.fill"),
            .init(time: "7p",   temperature: 28, precipitationProbability: 0.38, windSpeed: 16, windGust: 22, uvIndex: 0, cloudCover: 0.80, symbolName: "cloud.drizzle.fill"),
            .init(time: "8p",   temperature: 28, precipitationProbability: 0.18, windSpeed: 13, windGust: 18, uvIndex: 0, cloudCover: 0.70, symbolName: "cloud.fill"),
            .init(time: "9p",   temperature: 27, precipitationProbability: 0.12, windSpeed: 11, windGust: 15, uvIndex: 0, cloudCover: 0.55, symbolName: "cloud.fill"),
            .init(time: "10p",  temperature: 27, precipitationProbability: 0.08, windSpeed: 10, windGust: 13, uvIndex: 0, cloudCover: 0.40, symbolName: "moon.fill"),
            .init(time: "11p",  temperature: 26, precipitationProbability: 0.05, windSpeed: 8,  windGust: 11, uvIndex: 0, cloudCover: 0.30, symbolName: "moon.stars.fill"),
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
            locationSubtitle: "Default location · Uttar Pradesh, India",
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
