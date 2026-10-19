import Foundation
import os

/// Performance signpost instrumentation and session telemetry using OSSignposter.
public nonisolated final class AppSignposts: Sendable {
    public static let shared = AppSignposts()

    public let weatherSignposter: OSSignposter
    public let insightSignposter: OSSignposter

    private let fetchCounter = OSAllocatedUnfairLock(initialState: 0)

    public var sessionFetchCount: Int {
        fetchCounter.withLock { $0 }
    }

    public init() {
        self.weatherSignposter = OSSignposter(subsystem: "com.vedanshi.upthereapp", category: "WeatherFetch")
        self.insightSignposter = OSSignposter(subsystem: "com.vedanshi.upthereapp", category: "InsightEngine")
    }

    /// Records a completed weather fetch in the current session.
    public func recordWeatherFetch() {
        let count = fetchCounter.withLock { count -> Int in
            count += 1
            return count
        }
        let logger = Logger(subsystem: "com.vedanshi.upthereapp", category: "WeatherFetch")
        logger.info("Weather fetch completed. Total session fetch count: \(count)")
    }
}
