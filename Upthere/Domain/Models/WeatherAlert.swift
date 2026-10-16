import Foundation

public struct WeatherAlert: Equatable, Sendable, Codable, Identifiable {
    public let id: String
    public let source: String
    public let title: String
    public let validUntil: String
    public let details: String?
    public let severity: String?
    public let expirationDate: Date?

    public init(
        id: String? = nil,
        source: String,
        title: String,
        validUntil: String,
        details: String? = nil,
        severity: String? = nil,
        expirationDate: Date? = nil
    ) {
        self.id = id ?? "\(source)_\(title)_\(validUntil)"
        self.source = source
        self.title = title
        self.validUntil = validUntil
        self.details = details
        self.severity = severity
        self.expirationDate = expirationDate
    }

    public var isExpired: Bool {
        if let expirationDate = expirationDate {
            return expirationDate < Date()
        }
        return false
    }

    enum CodingKeys: String, CodingKey {
        case id, source, title, validUntil, details, severity, expirationDate
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let source = try container.decode(String.self, forKey: .source)
        let title = try container.decode(String.self, forKey: .title)
        let validUntil = try container.decode(String.self, forKey: .validUntil)
        self.id = try container.decodeIfPresent(String.self, forKey: .id) ?? "\(source)_\(title)_\(validUntil)"
        self.source = source
        self.title = title
        self.validUntil = validUntil
        self.details = try container.decodeIfPresent(String.self, forKey: .details)
        self.severity = try container.decodeIfPresent(String.self, forKey: .severity)
        self.expirationDate = try container.decodeIfPresent(Date.self, forKey: .expirationDate)
    }
}
