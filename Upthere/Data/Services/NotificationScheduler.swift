import Foundation
import UserNotifications

enum NotificationAuthorizationStatus: Sendable, Equatable {
    case notDetermined
    case authorized
    case denied
}

struct LocalNotificationRequest: Equatable, Sendable {
    let id: String
    let title: String
    let body: String
    let fireDate: Date?

    init(id: String, title: String, body: String, fireDate: Date? = nil) {
        self.id = id
        self.title = title
        self.body = body
        self.fireDate = fireDate
    }
}

protocol NotificationSchedulerProtocol: AnyObject, Sendable {
    func requestAuthorization() async -> Bool
    func authorizationStatus() async -> NotificationAuthorizationStatus
    func schedule(_ request: LocalNotificationRequest) async throws
    func cancel(id: String) async
    func cancelAll() async
    func isAlertDelivered(id: String) -> Bool
    func markAlertDelivered(id: String)
}

extension NotificationSchedulerProtocol {
    func handleWeatherRefresh(
        weather: Weather,
        rainAlertsEnabled: Bool,
        severeAlertsEnabled: Bool,
        now: Date = Date()
    ) async {
        // 1. Rain alert handling: cancel existing so there are no duplicates
        await cancel(id: NotificationScheduler.rainAlertId)

        if rainAlertsEnabled,
           let rainWindow = InsightEngine().rainWindow(from: weather.hourlyForecast) {
            let timeUntilRain = rainWindow.startDate.timeIntervalSince(now)
            if timeUntilRain > 0 && timeUntilRain <= 2 * 3600 {
                let fireDate = rainWindow.startDate.addingTimeInterval(-15 * 60)
                let rainRequest = LocalNotificationRequest(
                    id: NotificationScheduler.rainAlertId,
                    title: "Rain Expected Soon",
                    body: "Rain starting in \(weather.cityName) in about 15 minutes.",
                    fireDate: fireDate
                )
                try? await schedule(rainRequest)
            }
        }

        // 2. Severe alert handling: immediate notification once per alert id
        if severeAlertsEnabled,
           let alert = weather.alert,
           !alert.isExpired,
           !isAlertDelivered(id: alert.id) {
            let severeRequest = LocalNotificationRequest(
                id: "\(NotificationScheduler.severeAlertIdPrefix)\(alert.id)",
                title: alert.title,
                body: alert.details ?? alert.validUntil,
                fireDate: nil
            )
            try? await schedule(severeRequest)
            markAlertDelivered(id: alert.id)
        }
    }
}

final class NotificationScheduler: NotificationSchedulerProtocol, @unchecked Sendable {
    static let shared = NotificationScheduler()

    static let rainAlertId = "upthere.notification.rain"
    static let severeAlertIdPrefix = "upthere.notification.severe."

    private let center: UNUserNotificationCenter
    private let defaults: UserDefaults
    private let deliveredAlertsKey = "upthere.notifications.delivered_alerts"

    init(
        center: UNUserNotificationCenter = .current(),
        defaults: UserDefaults = AppGroup.defaults
    ) {
        self.center = center
        self.defaults = defaults
    }

    func requestAuthorization() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            return granted
        } catch {
            return false
        }
    }

    func authorizationStatus() async -> NotificationAuthorizationStatus {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return .authorized
        case .denied:
            return .denied
        case .notDetermined:
            fallthrough
        @unknown default:
            return .notDetermined
        }
    }

    func schedule(_ request: LocalNotificationRequest) async throws {
        let content = UNMutableNotificationContent()
        content.title = request.title
        content.body = request.body
        content.sound = .default

        let trigger: UNNotificationTrigger?
        if let fireDate = request.fireDate {
            let interval = fireDate.timeIntervalSinceNow
            if interval > 0 {
                trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
            } else {
                trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
            }
        } else {
            trigger = nil
        }

        let unRequest = UNNotificationRequest(identifier: request.id, content: content, trigger: trigger)
        try await center.add(unRequest)
    }

    func cancel(id: String) async {
        center.removePendingNotificationRequests(withIdentifiers: [id])
        center.removeDeliveredNotifications(withIdentifiers: [id])
    }

    func cancelAll() async {
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
    }

    func isAlertDelivered(id: String) -> Bool {
        let delivered = defaults.stringArray(forKey: deliveredAlertsKey) ?? []
        return delivered.contains(id)
    }

    func markAlertDelivered(id: String) {
        var delivered = defaults.stringArray(forKey: deliveredAlertsKey) ?? []
        if !delivered.contains(id) {
            delivered.append(id)
            defaults.set(delivered, forKey: deliveredAlertsKey)
        }
    }
}

// MARK: - Fake Scheduler for Unit Tests

#if DEBUG
final class FakeNotificationScheduler: NotificationSchedulerProtocol, @unchecked Sendable {
    var authorizationStatusToReturn: NotificationAuthorizationStatus = .authorized
    var requestAuthorizationResult: Bool = true
    private(set) var requestAuthorizationCallCount: Int = 0

    private(set) var scheduledRequests: [LocalNotificationRequest] = []
    private(set) var cancelledIds: [String] = []
    var deliveredAlertIds: Set<String> = []

    init(
        authorizationStatus: NotificationAuthorizationStatus = .authorized,
        requestAuthorizationResult: Bool = true
    ) {
        self.authorizationStatusToReturn = authorizationStatus
        self.requestAuthorizationResult = requestAuthorizationResult
    }

    func requestAuthorization() async -> Bool {
        requestAuthorizationCallCount += 1
        if requestAuthorizationResult {
            authorizationStatusToReturn = .authorized
        } else {
            authorizationStatusToReturn = .denied
        }
        return requestAuthorizationResult
    }

    func authorizationStatus() async -> NotificationAuthorizationStatus {
        authorizationStatusToReturn
    }

    func schedule(_ request: LocalNotificationRequest) async throws {
        scheduledRequests.removeAll { $0.id == request.id }
        scheduledRequests.append(request)
    }

    func cancel(id: String) async {
        cancelledIds.append(id)
        scheduledRequests.removeAll { $0.id == id }
    }

    func cancelAll() async {
        scheduledRequests.removeAll()
    }

    func isAlertDelivered(id: String) -> Bool {
        deliveredAlertIds.contains(id)
    }

    func markAlertDelivered(id: String) {
        deliveredAlertIds.insert(id)
    }
}
#endif

