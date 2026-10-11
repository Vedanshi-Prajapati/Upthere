import Foundation

public struct RainWindow: Equatable, Sendable, Codable {
    public let title: String        // e.g. "Rain likely later"
    public let timeRange: String    // e.g. "4:00 PM – 6:30 PM"
    public let detail: String       // e.g. "Most likely near 5 PM, at 70% probability."

    public init(title: String, timeRange: String, detail: String) {
        self.title = title
        self.timeRange = timeRange
        self.detail = detail
    }
}
