import Foundation

public struct DailyWeather: Equatable, Sendable, Identifiable, Codable {
    public let id: UUID
    public let dayName: String
    public let date: String
    public let symbolName: String
    public let precipitationProbability: Double
    public let lowTemperature: Double
    public let highTemperature: Double

    public init(
        id: UUID = UUID(),
        dayName: String,
        date: String,
        symbolName: String,
        precipitationProbability: Double = 0,
        lowTemperature: Double,
        highTemperature: Double
    ) {
        self.id = id
        self.dayName = dayName
        self.date = date
        self.symbolName = symbolName.isEmpty ? "cloud.sun.fill" : symbolName
        let p = precipitationProbability.isNaN || precipitationProbability.isInfinite ? 0.0 : precipitationProbability
        self.precipitationProbability = max(0.0, min(1.0, p))

        let rawLow = lowTemperature.isNaN || lowTemperature.isInfinite ? 20.0 : lowTemperature
        let rawHigh = highTemperature.isNaN || highTemperature.isInfinite ? 25.0 : highTemperature
        // Enforce lowTemperature <= highTemperature
        self.lowTemperature = min(rawLow, rawHigh)
        self.highTemperature = max(rawLow, rawHigh)
    }
}
