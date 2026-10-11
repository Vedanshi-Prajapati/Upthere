import Foundation

public struct WeatherAlert: Equatable, Sendable, Codable {
    public let source: String
    public let title: String
    public let validUntil: String
    public let details: String?
    public let severity: String?
    public let expirationDate: Date?

    public init(
        source: String,
        title: String,
        validUntil: String,
        details: String? = nil,
        severity: String? = nil,
        expirationDate: Date? = nil
    ) {
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
}
