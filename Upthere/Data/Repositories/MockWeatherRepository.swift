import Foundation

public enum MockWeatherError: LocalizedError {
    case simulatedFailure

    public var errorDescription: String? {
        "Failed to load weather data (simulated error)."
    }
}

public final class MockWeatherRepository: WeatherRepository {
    private let mockWeather: Weather?
    private let shouldFail: Bool

    public init(
        mockWeather: Weather? = nil,
        shouldFail: Bool = false
    ) {
        self.mockWeather = mockWeather
        self.shouldFail = shouldFail
    }

    public func fetchCurrentWeather() async throws -> Weather {
        try await Task.sleep(nanoseconds: 300_000_000)

        if shouldFail {
            throw MockWeatherError.simulatedFailure
        }

        return mockWeather ?? Weather(
            cityName: "San Francisco",
            temperature: 68.0,
            condition: "Partly Cloudy",
            highTemperature: 72.0,
            lowTemperature: 55.0
        )
    }
}
