import Foundation

public struct HourlyWeather: Equatable, Sendable, Identifiable, Codable {
    public let id: UUID
    public let date: Date
    public let temperature: Double
    public let feelsLike: Double
    public let precipitationChance: Double // 0.0 – 1.0
    public let precipitationAmount: Double // mm
    public let windSpeed: Double // km/h
    public let windGust: Double // km/h
    public let uvIndex: Int
    public let cloudCover: Double // 0.0 – 1.0
    public let symbolName: String
    public let isDaylight: Bool
    private let customTimeString: String?

    private enum CodingKeys: String, CodingKey {
        case id, date, temperature, feelsLike, precipitationChance, precipitationAmount
        case windSpeed, windGust, uvIndex, cloudCover, symbolName, isDaylight
    }

    // MARK: - Convenience Accessors
    public var precipitationProbability: Double { precipitationChance }
    public var wind: Double { windSpeed }
    public var gust: Double { windGust }
    public var symbol: String { symbolName }

    // MARK: - Compatibility Formatted Display
    public var time: String {
        if let customTimeString {
            return customTimeString
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "ha"
        return formatter.string(from: date).lowercased().replacingOccurrences(of: "m", with: "")
    }

    public init(
        id: UUID = UUID(),
        date: Date = Date(),
        temperature: Double,
        feelsLike: Double? = nil,
        precipitationChance: Double,
        precipitationAmount: Double = 0.0,
        windSpeed: Double = 0.0,
        windGust: Double = 0.0,
        uvIndex: Int = 0,
        cloudCover: Double = 0.0,
        symbolName: String = "cloud.sun.fill",
        isDaylight: Bool = true
    ) {
        self.id = id
        self.date = date
        self.customTimeString = nil

        // Sanitize non-finite values or extreme implausibilities
        if temperature.isNaN || temperature.isInfinite {
            self.temperature = 20.0
        } else {
            self.temperature = temperature
        }

        let fl = feelsLike ?? self.temperature
        self.feelsLike = (fl.isNaN || fl.isInfinite) ? self.temperature : fl

        let p = precipitationChance.isNaN || precipitationChance.isInfinite ? 0.0 : precipitationChance
        self.precipitationChance = max(0.0, min(1.0, p))

        let pa = precipitationAmount.isNaN || precipitationAmount.isInfinite ? 0.0 : precipitationAmount
        self.precipitationAmount = max(0.0, pa)

        let w = windSpeed.isNaN || windSpeed.isInfinite ? 0.0 : windSpeed
        self.windSpeed = max(0.0, w)

        let g = windGust.isNaN || windGust.isInfinite ? self.windSpeed : windGust
        self.windGust = max(self.windSpeed, g)

        self.uvIndex = max(0, uvIndex)

        let c = cloudCover.isNaN || cloudCover.isInfinite ? 0.0 : cloudCover
        self.cloudCover = max(0.0, min(1.0, c))

        self.symbolName = symbolName.isEmpty ? "cloud.sun.fill" : symbolName
        self.isDaylight = isDaylight
    }

    // Convenience initializer for backwards compatibility with tests and callers passing precipitationProbability
    public init(
        id: UUID = UUID(),
        time: String? = nil,
        date: Date = Date(),
        temperature: Double,
        feelsLike: Double? = nil,
        precipitationProbability: Double,
        precipitationAmount: Double = 0.0,
        windSpeed: Double = 0.0,
        windGust: Double = 0.0,
        uvIndex: Int = 0,
        cloudCover: Double = 0.0,
        symbolName: String = "cloud.sun.fill",
        isDaylight: Bool = true
    ) {
        self.id = id
        self.date = date
        self.customTimeString = time

        if temperature.isNaN || temperature.isInfinite {
            self.temperature = 20.0
        } else {
            self.temperature = temperature
        }

        let fl = feelsLike ?? self.temperature
        self.feelsLike = (fl.isNaN || fl.isInfinite) ? self.temperature : fl

        let p = precipitationProbability.isNaN || precipitationProbability.isInfinite ? 0.0 : precipitationProbability
        self.precipitationChance = max(0.0, min(1.0, p))

        let pa = precipitationAmount.isNaN || precipitationAmount.isInfinite ? 0.0 : precipitationAmount
        self.precipitationAmount = max(0.0, pa)

        let w = windSpeed.isNaN || windSpeed.isInfinite ? 0.0 : windSpeed
        self.windSpeed = max(0.0, w)

        let g = windGust.isNaN || windGust.isInfinite ? self.windSpeed : windGust
        self.windGust = max(self.windSpeed, g)

        self.uvIndex = max(0, uvIndex)

        let c = cloudCover.isNaN || cloudCover.isInfinite ? 0.0 : cloudCover
        self.cloudCover = max(0.0, min(1.0, c))

        self.symbolName = symbolName.isEmpty ? "cloud.sun.fill" : symbolName
        self.isDaylight = isDaylight
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.date = try container.decodeIfPresent(Date.self, forKey: .date) ?? Date()
        self.temperature = try container.decode(Double.self, forKey: .temperature)
        self.feelsLike = try container.decodeIfPresent(Double.self, forKey: .feelsLike) ?? self.temperature
        self.precipitationChance = try container.decode(Double.self, forKey: .precipitationChance)
        self.precipitationAmount = try container.decodeIfPresent(Double.self, forKey: .precipitationAmount) ?? 0.0
        self.windSpeed = try container.decodeIfPresent(Double.self, forKey: .windSpeed) ?? 0.0
        self.windGust = try container.decodeIfPresent(Double.self, forKey: .windGust) ?? self.windSpeed
        self.uvIndex = try container.decodeIfPresent(Int.self, forKey: .uvIndex) ?? 0
        self.cloudCover = try container.decodeIfPresent(Double.self, forKey: .cloudCover) ?? 0.0
        self.symbolName = try container.decodeIfPresent(String.self, forKey: .symbolName) ?? "cloud.sun.fill"
        self.isDaylight = try container.decodeIfPresent(Bool.self, forKey: .isDaylight) ?? true
        self.customTimeString = nil
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(date, forKey: .date)
        try container.encode(temperature, forKey: .temperature)
        try container.encode(feelsLike, forKey: .feelsLike)
        try container.encode(precipitationChance, forKey: .precipitationChance)
        try container.encode(precipitationAmount, forKey: .precipitationAmount)
        try container.encode(windSpeed, forKey: .windSpeed)
        try container.encode(windGust, forKey: .windGust)
        try container.encode(uvIndex, forKey: .uvIndex)
        try container.encode(cloudCover, forKey: .cloudCover)
        try container.encode(symbolName, forKey: .symbolName)
        try container.encode(isDaylight, forKey: .isDaylight)
    }
}
