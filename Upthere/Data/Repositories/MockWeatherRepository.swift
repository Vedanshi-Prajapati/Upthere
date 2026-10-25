import Foundation
import CoreLocation
#if DEBUG
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
        let baseDate = Date()
        let calendar = Calendar.current

        func hourDate(_ offset: Int) -> Date {
            calendar.date(byAdding: .hour, value: offset, to: baseDate) ?? baseDate.addingTimeInterval(Double(offset) * 3600)
        }

        let hourly: [HourlyWeather] = [
            HourlyWeather(date: hourDate(0),  temperature: 28, feelsLike: 30, precipitationChance: 0.05, precipitationAmount: 0.0, windSpeed: 10, windGust: 14, uvIndex: 3,  cloudCover: 0.30, symbolName: "cloud.sun.fill", isDaylight: true),
            HourlyWeather(date: hourDate(1),  temperature: 29, feelsLike: 31, precipitationChance: 0.05, precipitationAmount: 0.0, windSpeed: 11, windGust: 15, uvIndex: 5,  cloudCover: 0.35, symbolName: "sun.max.fill", isDaylight: true),
            HourlyWeather(date: hourDate(2),  temperature: 31, feelsLike: 33, precipitationChance: 0.07, precipitationAmount: 0.0, windSpeed: 13, windGust: 17, uvIndex: 7,  cloudCover: 0.40, symbolName: "sun.max.fill", isDaylight: true),
            HourlyWeather(date: hourDate(3),  temperature: 32, feelsLike: 34, precipitationChance: 0.10, precipitationAmount: 0.0, windSpeed: 14, windGust: 18, uvIndex: 9,  cloudCover: 0.45, symbolName: "cloud.sun.fill", isDaylight: true),
            HourlyWeather(date: hourDate(4),  temperature: 33, feelsLike: 36, precipitationChance: 0.15, precipitationAmount: 0.0, windSpeed: 16, windGust: 22, uvIndex: 11, cloudCover: 0.50, symbolName: "cloud.sun.fill", isDaylight: true),
            HourlyWeather(date: hourDate(5),  temperature: 35, feelsLike: 38, precipitationChance: 0.20, precipitationAmount: 0.0, windSpeed: 18, windGust: 25, uvIndex: 10, cloudCover: 0.60, symbolName: "cloud.fill", isDaylight: true),
            HourlyWeather(date: hourDate(6),  temperature: 34, feelsLike: 37, precipitationChance: 0.30, precipitationAmount: 0.2, windSpeed: 20, windGust: 28, uvIndex: 8,  cloudCover: 0.70, symbolName: "cloud.fill", isDaylight: true),
            HourlyWeather(date: hourDate(7),  temperature: 33, feelsLike: 36, precipitationChance: 0.42, precipitationAmount: 1.5, windSpeed: 22, windGust: 30, uvIndex: 5,  cloudCover: 0.85, symbolName: "cloud.bolt.rain.fill", isDaylight: true),
            HourlyWeather(date: hourDate(8),  temperature: 31, feelsLike: 34, precipitationChance: 0.65, precipitationAmount: 4.0, windSpeed: 25, windGust: 35, uvIndex: 2,  cloudCover: 0.95, symbolName: "cloud.rain.fill", isDaylight: true),
            HourlyWeather(date: hourDate(9),  temperature: 30, feelsLike: 33, precipitationChance: 0.70, precipitationAmount: 5.5, windSpeed: 24, windGust: 34, uvIndex: 1,  cloudCover: 0.95, symbolName: "cloud.rain.fill", isDaylight: true),
            HourlyWeather(date: hourDate(10), temperature: 29, feelsLike: 31, precipitationChance: 0.60, precipitationAmount: 3.0, windSpeed: 20, windGust: 28, uvIndex: 0,  cloudCover: 0.90, symbolName: "cloud.rain.fill", isDaylight: false),
            HourlyWeather(date: hourDate(11), temperature: 28, feelsLike: 30, precipitationChance: 0.38, precipitationAmount: 0.8, windSpeed: 16, windGust: 22, uvIndex: 0,  cloudCover: 0.80, symbolName: "cloud.drizzle.fill", isDaylight: false),
            HourlyWeather(date: hourDate(12), temperature: 28, feelsLike: 29, precipitationChance: 0.18, precipitationAmount: 0.0, windSpeed: 13, windGust: 18, uvIndex: 0,  cloudCover: 0.70, symbolName: "cloud.fill", isDaylight: false),
            HourlyWeather(date: hourDate(13), temperature: 27, feelsLike: 28, precipitationChance: 0.12, precipitationAmount: 0.0, windSpeed: 11, windGust: 15, uvIndex: 0,  cloudCover: 0.55, symbolName: "cloud.fill", isDaylight: false),
            HourlyWeather(date: hourDate(14), temperature: 27, feelsLike: 28, precipitationChance: 0.08, precipitationAmount: 0.0, windSpeed: 10, windGust: 13, uvIndex: 0,  cloudCover: 0.40, symbolName: "moon.fill", isDaylight: false),
            HourlyWeather(date: hourDate(15), temperature: 26, feelsLike: 27, precipitationChance: 0.05, precipitationAmount: 0.0, windSpeed: 8,  windGust: 11, uvIndex: 0,  cloudCover: 0.30, symbolName: "moon.stars.fill", isDaylight: false)
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

    public static func makeWeather(condition: String, symbolName: String, temperature: Double = 24) -> Weather {
        let base = makeGhaziabadWeather()
        return Weather(
            cityName: "Ghaziabad",
            locationSubtitle: "Default location · Uttar Pradesh, India",
            temperature: temperature,
            condition: condition,
            highTemperature: temperature + 6,
            lowTemperature: temperature - 4,
            feelsLike: temperature + 2,
            weatherSymbolName: symbolName,
            description: "\(condition) conditions across the area today.",
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
}
#endif
