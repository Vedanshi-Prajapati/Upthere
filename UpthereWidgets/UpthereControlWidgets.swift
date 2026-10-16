import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Control Center Quick Weather Button (iOS 18+)

@available(iOS 18.0, *)
struct UpthereQuickWeatherControl: ControlWidget {
    static let kind: String = "com.vedanshi.upthere.control.quickweather"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: LaunchUpthereControlIntent()) {
                Label("UpThere", systemImage: "cloud.sun.fill")
            }
        }
        .displayName("UpThere Weather")
        .description("Quickly check current weather or rain likelihood in UpThere.")
    }
}

// MARK: - Control Center Severe Alerts Toggle (iOS 18+)

@available(iOS 18.0, *)
struct UpthereAlertsControl: ControlWidget {
    static let kind: String = "com.vedanshi.upthere.control.alerts"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetToggle(
                "Severe Alerts",
                isOn: AppGroup.defaults.bool(forKey: AppGroup.severeAlertsKey),
                action: ToggleSevereAlertsControlIntent()
            ) { isOn in
                Label(isOn ? "Alerts Active" : "Alerts Muted", systemImage: isOn ? "bell.badge.fill" : "bell.slash")
            }
        }
        .displayName("Severe Weather Alerts")
        .description("Toggle severe weather alert notifications directly from Control Center.")
    }
}

// MARK: - Control Intents

@available(iOS 18.0, *)
struct LaunchUpthereControlIntent: AppIntent {
    static var title: LocalizedStringResource = "Open UpThere"
    static var description = IntentDescription("Launches UpThere directly from Control Center.")
    static var openAppWhenRun: Bool = true

    init() {}

    func perform() async throws -> some IntentResult {
        return .result()
    }
}

@available(iOS 18.0, *)
struct ToggleSevereAlertsControlIntent: SetValueIntent {
    static var title: LocalizedStringResource = "Toggle Severe Alerts"
    static var description = IntentDescription("Turn severe weather alerts on or off from Control Center.")

    @Parameter(title: "Alerts Enabled")
    var value: Bool

    init() { self.value = true }
    init(value: Bool) { self.value = value }

    func perform() async throws -> some IntentResult {
        AppGroup.defaults.set(value, forKey: AppGroup.severeAlertsKey)
        WidgetCenter.shared.reloadAllTimelines()
        ControlCenter.shared.reloadAllControls()
        return .result()
    }
}
