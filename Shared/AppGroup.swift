import Foundation

public enum AppGroup: Sendable {
    public static let identifier = "group.com.vedanshi.upthereapp"

    /// Shared UserDefaults suite for sharing state across the app, widget, and controls.
    public static var defaults: UserDefaults {
        UserDefaults(suiteName: identifier) ?? .standard
    }

    /// Shared App Group container URL.
    public static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
    }

    /// Returns a subfolder URL within the App Group container, creating it if needed.
    public static func containerURL(forSubdirectory subdirectory: String) -> URL? {
        guard let base = containerURL else { return nil }
        let dir = base.appendingPathComponent(subdirectory, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    // MARK: - Migration Keys
    public static let settingsKeys = [
        "settings.temperatureUnit",
        "settings.windSpeedUnit",
        "settings.precipitationUnit",
        "settings.appearanceMode",
        "settings.weatherChangesEnabled",
        "settings.rainAlertsEnabled",
        "settings.severeAlertsEnabled"
    ]

    public static let migrationKey = "upthere.settings.migrated_to_app_group"

    /// Migrates existing values from standard UserDefaults into the App Group suite exactly once.
    /// Does not overwrite existing values in the group suite or subsequent modifications.
    public static func migrateSettingsIfNeeded(
        standard: UserDefaults = .standard,
        group: UserDefaults = AppGroup.defaults
    ) {
        guard !group.bool(forKey: migrationKey) else { return }

        for key in settingsKeys {
            if let value = standard.object(forKey: key), group.object(forKey: key) == nil {
                group.set(value, forKey: key)
            }
        }

        // Also migrate any cached weather payloads
        for (key, value) in standard.dictionaryRepresentation() {
            if key.hasPrefix("upthere.weather.cache.") && group.object(forKey: key) == nil {
                group.set(value, forKey: key)
            }
        }

        group.set(true, forKey: migrationKey)
    }
}
