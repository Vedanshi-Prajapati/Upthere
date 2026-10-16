import Foundation
import ActivityKit
import OSLog

@MainActor
public final class RainActivityManager {
    public static let shared = RainActivityManager()

    private let logger = Logger(subsystem: "com.vedanshi.upthereapp", category: "RainActivityManager")
    private let insightEngine = InsightEngine()

    public init() {}

    /// Checks if Live Activities are enabled and if an active rain activity exists
    public var hasActiveActivity: Bool {
        !Activity<RainStartActivityAttributes>.activities.isEmpty
    }

    /// The first active rain activity if present
    public var activeActivity: Activity<RainStartActivityAttributes>? {
        Activity<RainStartActivityAttributes>.activities.first
    }

    /// Starts a RainStartActivity for the specified city and hourly forecast
    @discardableResult
    public func startRainActivity(
        city: String,
        hourly: [HourlyWeather],
        now: Date = Date()
    ) async -> Bool {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            logger.info("Live Activities are not enabled by the user.")
            return false
        }

        guard let rainWindow = insightEngine.rainWindow(from: hourly),
              RainActivityStateCalculator.isRainWithinTwoHours(rainWindow: rainWindow, now: now),
              let calculation = RainActivityStateCalculator.calculateState(rainWindow: rainWindow, now: now),
              !calculation.isEnded else {
            logger.info("No active rain window within 2 hours to start activity for \(city).")
            return false
        }

        // End any existing activities first
        await endAllRainActivities(dismissalPolicy: .immediate)

        let attributes = RainStartActivityAttributes(city: city)
        let contentState = calculation.contentState
        let activityContent = ActivityContent(
            state: contentState,
            staleDate: calculation.endTime
        )

        do {
            let activity = try Activity<RainStartActivityAttributes>.request(
                attributes: attributes,
                content: activityContent,
                pushType: nil
            )
            logger.info("Successfully started RainStartActivity \(activity.id) for \(city).")
            return true
        } catch {
            logger.error("Failed to request Live Activity: \(error.localizedDescription)")
            return false
        }
    }

    /// Updates existing RainStartActivities on foreground refresh
    public func updateOnForegroundRefresh(
        hourly: [HourlyWeather],
        city: String? = nil,
        now: Date = Date()
    ) async {
        let activities = Activity<RainStartActivityAttributes>.activities
        guard !activities.isEmpty else { return }

        let rainWindow = insightEngine.rainWindow(from: hourly)
        guard let window = rainWindow,
              let calculation = RainActivityStateCalculator.calculateState(rainWindow: window, now: now),
              !calculation.isEnded else {
            // Rain window has passed or cleared — end all activities
            logger.info("Rain window has passed or ended; ending live activities.")
            await endAllRainActivities(dismissalPolicy: .immediate)
            return
        }

        let contentState = calculation.contentState
        let updatedContent = ActivityContent(
            state: contentState,
            staleDate: calculation.endTime
        )

        for activity in activities {
            await activity.update(updatedContent)
            logger.info("Updated RainStartActivity \(activity.id) with \(calculation.minutesUntilRain)m remaining.")
        }
    }

    /// Ends all active RainStartActivities
    public func endAllRainActivities(dismissalPolicy: ActivityUIDismissalPolicy = .immediate) async {
        for activity in Activity<RainStartActivityAttributes>.activities {
            let finalContent = ActivityContent(state: activity.content.state, staleDate: nil)
            await activity.end(finalContent, dismissalPolicy: dismissalPolicy)
        }
    }
}
