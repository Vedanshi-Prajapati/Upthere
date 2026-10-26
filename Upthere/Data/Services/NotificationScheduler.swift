import Foundation
import UserNotifications
import os

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

typealias NotificationScheduling = NotificationSchedulerProtocol

protocol NotificationSchedulerProtocol: AnyObject, Sendable {
    func requestAuthorization() async -> Bool
    func authorizationStatus() async -> NotificationAuthorizationStatus
    func schedule(_ request: LocalNotificationRequest) async throws
    func cancel(id: String) async
    func cancelAll() async
    func isAlertDelivered(id: String) -> Bool
    func markAlertDelivered(id: String)
    func handleWeatherRefresh(
        weather: Weather,
        rainAlertsEnabled: Bool,
        severeAlertsEnabled: Bool,
        now: Date
    ) async
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
                do {
                    try await schedule(rainRequest)
                } catch {
                    let logger = Logger(subsystem: "com.vedanshi.upthereapp", category: "Notifications")
                    logger.error("Failed to schedule rain notification: \(error.localizedDescription)")
                }
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
            do {
                try await schedule(severeRequest)
                markAlertDelivered(id: alert.id)
            } catch {
                let logger = Logger(subsystem: "com.vedanshi.upthereapp", category: "Notifications")
                logger.error("Failed to schedule severe alert notification: \(error.localizedDescription)")
            }
        }
    }
}

/// Lock-protected notification scheduler coordinating local alerts across processes.
/// Invariant: Access to delivered alerts in UserDefaults is synchronized via `lock`.
final class NotificationScheduler: NotificationSchedulerProtocol, @unchecked Sendable {
    static let shared = NotificationScheduler()

    static let rainAlertId = "upthere.notification.rain"
    static let severeAlertIdPrefix = "upthere.notification.severe."

    private let lock = NSLock()
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
        lock.withLock {
            let delivered = defaults.stringArray(forKey: deliveredAlertsKey) ?? []
            return delivered.contains(id)
        }
    }

    func markAlertDelivered(id: String) {
        lock.withLock {
            var delivered = defaults.stringArray(forKey: deliveredAlertsKey) ?? []
            if !delivered.contains(id) {
                delivered.append(id)
                defaults.set(delivered, forKey: deliveredAlertsKey)
            }
        }
    }
}

// MARK: - Fake Scheduler for Unit Tests

#if DEBUG
/// Lock-protected test double for notification scheduling.
/// Invariant: All mutable state (call counts, scheduled requests, cancelled IDs, delivered alert IDs)
/// is synchronized via `lock` to ensure safe concurrent test assertions.
final class FakeNotificationScheduler: NotificationSchedulerProtocol, @unchecked Sendable {
    private let lock = NSLock()
    private var _authorizationStatusToReturn: NotificationAuthorizationStatus = .authorized
    private var _requestAuthorizationResult: Bool = true
    private var _requestAuthorizationCallCount: Int = 0

    private var _scheduledRequests: [LocalNotificationRequest] = []
    private var _cancelledIds: [String] = []
    private var _deliveredAlertIds: Set<String> = []

    var authorizationStatusToReturn: NotificationAuthorizationStatus {
        get { lock.withLock { _authorizationStatusToReturn } }
        set { lock.withLock { _authorizationStatusToReturn = newValue } }
    }

    var requestAuthorizationResult: Bool {
        get { lock.withLock { _requestAuthorizationResult } }
        set { lock.withLock { _requestAuthorizationResult = newValue } }
    }

    var requestAuthorizationCallCount: Int {
        lock.withLock { _requestAuthorizationCallCount }
    }

    var scheduledRequests: [LocalNotificationRequest] {
        lock.withLock { _scheduledRequests }
    }

    var cancelledIds: [String] {
        lock.withLock { _cancelledIds }
    }

    var deliveredAlertIds: Set<String> {
        get { lock.withLock { _deliveredAlertIds } }
        set { lock.withLock { _deliveredAlertIds = newValue } }
    }

    init(
        authorizationStatus: NotificationAuthorizationStatus = .authorized,
        requestAuthorizationResult: Bool = true
    ) {
        self._authorizationStatusToReturn = authorizationStatus
        self._requestAuthorizationResult = requestAuthorizationResult
    }

    func requestAuthorization() async -> Bool {
        lock.withLock {
            _requestAuthorizationCallCount += 1
            if _requestAuthorizationResult {
                _authorizationStatusToReturn = .authorized
            } else {
                _authorizationStatusToReturn = .denied
            }
            return _requestAuthorizationResult
        }
    }

    func authorizationStatus() async -> NotificationAuthorizationStatus {
        lock.withLock { _authorizationStatusToReturn }
    }

    func schedule(_ request: LocalNotificationRequest) async throws {
        lock.withLock {
            _scheduledRequests.removeAll { $0.id == request.id }
            _scheduledRequests.append(request)
        }
    }

    func cancel(id: String) async {
        lock.withLock {
            _cancelledIds.append(id)
            _scheduledRequests.removeAll { $0.id == id }
        }
    }

    func cancelAll() async {
        lock.withLock {
            _scheduledRequests.removeAll()
        }
    }

    func isAlertDelivered(id: String) -> Bool {
        lock.withLock {
            _deliveredAlertIds.contains(id)
        }
    }

    func markAlertDelivered(id: String) {
        lock.withLock {
            _deliveredAlertIds.insert(id)
        }
    }
}
#endif

