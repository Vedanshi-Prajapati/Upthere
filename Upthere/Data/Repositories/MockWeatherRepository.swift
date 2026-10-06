import Foundation

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
