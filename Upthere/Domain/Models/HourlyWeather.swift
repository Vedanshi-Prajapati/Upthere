import Foundation

public struct HourlyWeather: Equatable, Sendable, Identifiable, Codable {
    public let id: UUID
    public let time: String
    public let temperature: Double
    public let precipitationProbability: Double // 0.0 – 1.0
    public let windSpeed: Double // km/h
    public let windGust: Double // km/h
    public let uvIndex: Int
    public let cloudCover: Double // 0.0 – 1.0
    public let symbolName: String

    // Convenience accessors
    public var wind: Double { windSpeed }
    public var gust: Double { windGust }
    public var symbol: String { symbolName }

    public init(
        id: UUID = UUID(),
        time: String,
        temperature: Double,
        precipitationProbability: Double,
        windSpeed: Double = 0.0,
        windGust: Double = 0.0,
        uvIndex: Int = 0,
        cloudCover: Double = 0.0,
        symbolName: String = "cloud.sun.fill"
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

        let w = windSpeed.isNaN || windSpeed.isInfinite ? 0.0 : windSpeed
        self.windSpeed = max(0.0, w)

        let g = windGust.isNaN || windGust.isInfinite ? self.windSpeed : windGust
        self.windGust = max(self.windSpeed, g)

        self.uvIndex = max(0, uvIndex)

        let c = cloudCover.isNaN || cloudCover.isInfinite ? 0.0 : cloudCover
        self.cloudCover = max(0.0, min(1.0, c))

        self.symbolName = symbolName.isEmpty ? "cloud.sun.fill" : symbolName
    }
}
