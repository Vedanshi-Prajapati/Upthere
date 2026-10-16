import Foundation

public enum RainStateCalculationStatus: Equatable, Sendable {
    case rainPending(minutesUntilRain: Int)
    case rainStarted
    case rainEnded
}

public struct RainStateCalculationResult: Equatable, Sendable {
    public let status: RainStateCalculationStatus
    public let minutesUntilRain: Int
    public let intensity: String
    public let endTime: Date

    public var isEnded: Bool {
        status == .rainEnded
    }

    public var isRaining: Bool {
        status == .rainStarted
    }

    public init(
        status: RainStateCalculationStatus,
        minutesUntilRain: Int,
        intensity: String,
        endTime: Date
    ) {
        self.status = status
        self.minutesUntilRain = minutesUntilRain
        self.intensity = intensity
        self.endTime = endTime
    }

    public var contentState: RainStartActivityAttributes.ContentState {
        RainStartActivityAttributes.ContentState(
            minutesUntilRain: minutesUntilRain,
            intensity: intensity,
            endTime: endTime
        )
    }
}

public struct RainActivityStateCalculator: Sendable {
    public init() {}

    /// Formats intensity string based on peak rain probability and precipitation volume.
    public static func determineIntensity(peakProbability: Double, totalPrecipitation: Double = 0.0) -> String {
        if peakProbability >= 0.70 || totalPrecipitation >= 5.0 {
            return "Heavy rain"
        } else if peakProbability >= 0.45 || totalPrecipitation >= 1.5 {
            return "Moderate rain"
        } else {
            return "Light rain"
        }
    }

    /// Evaluates whether rain starts within 2 hours or is currently active.
    public static func isRainWithinTwoHours(
        rainWindow: InsightEngine.RainWindowResult?,
        now: Date = Date()
    ) -> Bool {
        guard let window = rainWindow else { return false }
        let diff = window.startDate.timeIntervalSince(now)
        if diff > 0 && diff <= 7200 {
            return true
        }
        if now >= window.startDate && now < window.endDate {
            return true
        }
        return false
    }

    /// Calculates state: minutes remaining, rain started, or rain ended.
    public static func calculateState(
        rainWindow: InsightEngine.RainWindowResult?,
        now: Date = Date()
    ) -> RainStateCalculationResult? {
        guard let window = rainWindow else {
            return nil
        }

        let intensity = determineIntensity(
            peakProbability: window.peakProbability,
            totalPrecipitation: window.totalPrecipitationAmount
        )

        // 1. Rain ended: current time has passed end date
        if now >= window.endDate {
            return RainStateCalculationResult(
                status: .rainEnded,
                minutesUntilRain: 0,
                intensity: intensity,
                endTime: window.endDate
            )
        }

        // 2. Rain started: current time is within [startDate, endDate)
        if now >= window.startDate {
            return RainStateCalculationResult(
                status: .rainStarted,
                minutesUntilRain: 0,
                intensity: intensity,
                endTime: window.endDate
            )
        }

        // 3. Rain pending: minutes remaining until startDate
        let diffSeconds = window.startDate.timeIntervalSince(now)
        let minutes = max(1, Int(round(diffSeconds / 60.0)))
        return RainStateCalculationResult(
            status: .rainPending(minutesUntilRain: minutes),
            minutesUntilRain: minutes,
            intensity: intensity,
            endTime: window.endDate
        )
    }
}
