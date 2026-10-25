import Foundation
import AppIntents
import WidgetKit

/// AppIntent to toggle Severe Weather Alerts from Shortcuts or Control Center
struct ToggleSevereAlertsIntent: AppIntent {
    static let title: LocalizedStringResource = "Toggle Severe Weather Alerts"
    static let description = IntentDescription("Turn severe weather alert notifications on or off in UpThere.")
    static let openAppWhenRun: Bool = false

    init() {}

    @MainActor
    func perform() async throws -> some ReturnsValue<Bool> & ProvidesDialog {
        let current = AppGroup.defaults.bool(forKey: AppGroup.severeAlertsKey)
        let newState = !current
        AppGroup.defaults.set(newState, forKey: AppGroup.severeAlertsKey)

        WidgetCenter.shared.reloadAllTimelines()
        if #available(iOS 18.0, *) {
            ControlCenter.shared.reloadAllControls()
        }

        let statusText = newState ? "enabled" : "disabled"
        return .result(
            value: newState,
            dialog: IntentDialog("Severe weather alerts are now \(statusText) in UpThere.")
        )
    }
}
