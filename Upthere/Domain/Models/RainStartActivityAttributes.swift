import Foundation
import ActivityKit

public nonisolated struct RainStartActivityAttributes: ActivityAttributes, Sendable {
    public struct ContentState: Codable, Hashable, Sendable {
        public var minutesUntilRain: Int
        public var intensity: String
        public var endTime: Date

        public init(minutesUntilRain: Int, intensity: String, endTime: Date) {
            self.minutesUntilRain = minutesUntilRain
            self.intensity = intensity
            self.endTime = endTime
        }
    }

    public var city: String

    public init(city: String) {
        self.city = city
    }
}
