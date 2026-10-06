import Foundation

public struct WeatherAlert: Equatable, Sendable {
    public let source: String
    public let title: String
    public let validUntil: String

    public init(source: String, title: String, validUntil: String) {
        self.source = source
        self.title = title
        self.validUntil = validUntil
    }
}
