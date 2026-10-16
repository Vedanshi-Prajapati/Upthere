import Foundation
import AppIntents

/// AppShortcutsProvider exposing Siri & Shortcuts shortcuts to the system
public struct UpthereShortcuts: AppShortcutsProvider {
    public static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CheckWeatherIntent(),
            phrases: [
                "Check Weather in \(.applicationName)",
                "What's the weather in \(.applicationName)",
                "How's the weather in \(.applicationName)",
                "Check rain in \(.applicationName)"
            ],
            shortTitle: "Check Weather",
            systemImageName: "cloud.sun.fill"
        )

        AppShortcut(
            intent: OpenLocationIntent(),
            phrases: [
                "Open \(\.$target) in \(.applicationName)",
                "Show \(\.$target) in \(.applicationName)"
            ],
            shortTitle: "Open Location",
            systemImageName: "mappin.and.ellipse"
        )

        AppShortcut(
            intent: ToggleSevereAlertsIntent(),
            phrases: [
                "Toggle severe alerts in \(.applicationName)",
                "Switch severe alerts in \(.applicationName)"
            ],
            shortTitle: "Toggle Severe Alerts",
            systemImageName: "exclamationmark.triangle.fill"
        )

        AppShortcut(
            intent: TrackRainIntent(),
            phrases: [
                "Track rain in \(.applicationName)",
                "Start rain tracking in \(.applicationName)",
                "Track rain with \(.applicationName)"
            ],
            shortTitle: "Track Rain",
            systemImageName: "cloud.rain.fill"
        )
    }

    public static var shortcutTileColor: ShortcutTileColor {
        .lightBlue
    }
}
