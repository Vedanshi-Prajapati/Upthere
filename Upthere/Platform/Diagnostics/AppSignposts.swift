import Foundation
import os

public protocol FetchMetrics: Sendable {
    func recordWeatherFetch()
}

/// Performance signpost instrumentation and session telemetry using OSSignposter.
nonisolated final class AppSignposts: FetchMetrics, Sendable {
    static let shared = AppSignposts()

    let weatherSignposter: OSSignposter
    let insightSignposter: OSSignposter

    private let fetchCounter = OSAllocatedUnfairLock(initialState: 0)

    var sessionFetchCount: Int {
        fetchCounter.withLock { $0 }
    }

    init() {
        self.weatherSignposter = OSSignposter(subsystem: "com.vedanshi.upthereapp", category: "WeatherFetch")
        self.insightSignposter = OSSignposter(subsystem: "com.vedanshi.upthereapp", category: "InsightEngine")
    }

    /// Records a completed weather fetch in the current session.
    func recordWeatherFetch() {
        let count = fetchCounter.withLock { count -> Int in
            count += 1
            return count
        }
        let logger = Logger(subsystem: "com.vedanshi.upthereapp", category: "WeatherFetch")
        logger.info("Weather fetch completed. Total session fetch count: \(count)")
    }
}
