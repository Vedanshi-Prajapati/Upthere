import Foundation

public struct HourlyWeather: Equatable, Sendable, Identifiable, Codable {
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
        // Sanitize non-finite values or extreme implausibilities
        if temperature.isNaN || temperature.isInfinite {
            self.temperature = 20.0
        } else {
            self.temperature = temperature
        }
        let p = precipitationProbability.isNaN || precipitationProbability.isInfinite ? 0.0 : precipitationProbability
        self.precipitationProbability = max(0.0, min(1.0, p))
    }
}
