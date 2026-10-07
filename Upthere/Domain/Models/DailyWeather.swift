import Foundation

public struct DailyWeather: Equatable, Sendable, Identifiable {
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
        self.symbolName = symbolName
        self.precipitationProbability = precipitationProbability
        self.lowTemperature = lowTemperature
        self.highTemperature = highTemperature
    }
}
