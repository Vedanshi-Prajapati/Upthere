import Foundation
import AppIntents

/// AppIntent to toggle Severe Weather Alerts from Shortcuts or Control Center
public struct ToggleSevereAlertsIntent: AppIntent {
    public static var title: LocalizedStringResource = "Toggle Severe Weather Alerts"
    public static var description = IntentDescription("Turn severe weather alert notifications on or off in UpThere.")
    public static var openAppWhenRun: Bool = false

    public init() {}

    @MainActor
    public func perform() async throws -> some ReturnsValue<Bool> & ProvidesDialog {
        let current = UserDefaults.standard.bool(forKey: "settings.severeAlertsEnabled")
        let newState = !current
        UserDefaults.standard.set(newState, forKey: "settings.severeAlertsEnabled")

        let statusText = newState ? "enabled" : "disabled"
        return .result(
            value: newState,
            dialog: IntentDialog("Severe weather alerts are now \(statusText) in UpThere.")
        )
    }
}
