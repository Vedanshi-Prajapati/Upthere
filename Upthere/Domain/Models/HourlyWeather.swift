import Foundation

public struct HourlyWeather: Equatable, Sendable, Identifiable {
    public let id: UUID
    public let time: String
    public let temperature: Double
    public let precipitationProbability: Double // 0.0 – 1.0

    public init(
        id: UUID = UUID(),
        time: String,
        temperature: Double,
        precipitationProbability: Double
    ) {
        self.id = id
        self.time = time
        self.temperature = temperature
        self.precipitationProbability = precipitationProbability
    }
}
