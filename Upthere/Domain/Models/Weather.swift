import Foundation

public struct Weather: Equatable, Sendable {
    public let cityName: String
    public let temperature: Double
    public let condition: String
    public let highTemperature: Double
    public let lowTemperature: Double

    public init(
        cityName: String,
        temperature: Double,
        condition: String,
        highTemperature: Double,
        lowTemperature: Double
    ) {
        self.cityName = cityName
        self.temperature = temperature
        self.condition = condition
        self.highTemperature = highTemperature
        self.lowTemperature = lowTemperature
    }
}
