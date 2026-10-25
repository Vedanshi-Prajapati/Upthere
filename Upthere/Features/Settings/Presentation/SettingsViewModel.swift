import Foundation
import Observation
import WidgetKit
import CoreLocation
import SwiftUI

@Observable
@MainActor
final class SettingsViewModel {
    let unitPreferences: UnitPreferences

    // MARK: - Weather Units
    var temperatureUnit: TemperatureUnit {
        get { unitPreferences.temperatureUnit }
        set { unitPreferences.temperatureUnit = newValue }
    }
    var windSpeedUnit: WindSpeedUnit {
        get { unitPreferences.windSpeedUnit }
        set { unitPreferences.windSpeedUnit = newValue }
    }
    var precipitationUnit: PrecipitationUnit {
        get { unitPreferences.precipitationUnit }
        set { unitPreferences.precipitationUnit = newValue }
    }

    // MARK: - Notifications
    var rainAlertsEnabled: Bool {
        didSet {
            defaults.set(rainAlertsEnabled, forKey: AppGroup.rainAlertsKey)
        }
    }
    var severeAlertsEnabled: Bool {
        didSet {
            defaults.set(severeAlertsEnabled, forKey: AppGroup.severeAlertsKey)
            WidgetCenter.shared.reloadAllTimelines()
            ControlCenter.shared.reloadAllControls()
        }
    }

    // MARK: - Spotlight
    var spotlightEnabled: Bool {
        didSet {
            defaults.set(spotlightEnabled, forKey: AppGroup.spotlightEnabledKey)
            if !spotlightEnabled {
                Task { @MainActor in
                    SpotlightService.shared.deindexAll()
                }
            }
        }
    }

    var notificationsDenied: Bool = false
    private let notificationScheduler: any NotificationSchedulerProtocol

    func checkNotificationStatus() async {
        let status = await notificationScheduler.authorizationStatus()
        notificationsDenied = (status == .denied)
    }

    func setRainAlerts(_ enabled: Bool) async {
        if enabled {
            let allowed = await requestNotificationPermissionIfNeeded()
            if !allowed {
                self.rainAlertsEnabled = false
                return
            }
        }
        self.rainAlertsEnabled = enabled
    }

    func setSevereAlerts(_ enabled: Bool) async {
        if enabled {
            let allowed = await requestNotificationPermissionIfNeeded()
            if !allowed {
                self.severeAlertsEnabled = false
                return
            }
        }
        self.severeAlertsEnabled = enabled
    }

    private func requestNotificationPermissionIfNeeded() async -> Bool {
        let status = await notificationScheduler.authorizationStatus()
        if status == .notDetermined {
            let granted = await notificationScheduler.requestAuthorization()
            if !granted {
                self.notificationsDenied = true
                return false
            }
            self.notificationsDenied = false
            return true
        } else if status == .denied {
            self.notificationsDenied = true
            return false
        } else {
            self.notificationsDenied = false
            return true
        }
    }

    // MARK: - Location
    let locationService: LocationService
    private let defaults: UserDefaults

    var currentLocationName: String {
        if locationService.isAuthorized {
            return locationService.currentCityName
        } else if locationService.authorizationStatus == .notDetermined {
            return "Not Determined"
        } else {
            return "Permission Denied"
        }
    }
    var locationPermission: String {
        switch locationService.authorizationStatus {
        case .authorizedWhenInUse: return "While Using"
        case .authorizedAlways:    return "Always"
        case .denied:              return "Denied"
        case .restricted:          return "Restricted"
        case .notDetermined:       return "Not Determined"
        @unknown default:          return "Unknown"
        }
    }

    // MARK: - Appearance
    var appearanceMode: AppearanceMode {
        didSet { defaults.set(appearanceMode.rawValue, forKey: "settings.appearanceMode") }
    }

    // MARK: - About
    let weatherDataProvider = "Apple WeatherKit"
    var appVersion: String {
        let shortVersion = bundle.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let buildVersion = bundle.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(shortVersion) (\(buildVersion))"
    }

    private let bundle: Bundle

    init(
        unitPreferences: UnitPreferences? = nil,
        locationService: LocationService? = nil,
        defaults: UserDefaults = AppGroup.defaults,
        notificationScheduler: (any NotificationSchedulerProtocol)? = nil,
        bundle: Bundle = .main
    ) {
        self.unitPreferences = unitPreferences ?? UnitPreferences(defaults: defaults)
        self.locationService = locationService ?? LocationService()
        self.defaults = defaults
        self.notificationScheduler = notificationScheduler ?? NotificationScheduler.shared
        self.bundle = bundle
        AppGroup.migrateSettingsIfNeeded(standard: .standard, group: defaults)

        if let rawApp = defaults.string(forKey: "settings.appearanceMode"),
           let mode = AppearanceMode(rawValue: rawApp) {
            self.appearanceMode = mode
        } else {
            self.appearanceMode = .system
        }

        if defaults.object(forKey: AppGroup.rainAlertsKey) != nil {
            self.rainAlertsEnabled = defaults.bool(forKey: AppGroup.rainAlertsKey)
        } else {
            self.rainAlertsEnabled = false
        }
        if defaults.object(forKey: AppGroup.severeAlertsKey) != nil {
            self.severeAlertsEnabled = defaults.bool(forKey: AppGroup.severeAlertsKey)
        } else {
            self.severeAlertsEnabled = false
        }
        if defaults.object(forKey: AppGroup.spotlightEnabledKey) != nil {
            self.spotlightEnabled = defaults.bool(forKey: AppGroup.spotlightEnabledKey)
        } else {
            self.spotlightEnabled = true
        }
    }

    // MARK: - Helpers

    func formatTemp(_ celsius: Double) -> String {
        let val = temperatureUnit.convert(celsius)
        return "\(Int(round(val)))°"
    }

    func formatWind(_ kmh: Double) -> String {
        let val = windSpeedUnit.convert(kmh: kmh)
        return "\(Int(round(val))) \(windSpeedUnit.rawValue)"
    }
}

// MARK: - AppearanceMode Enum

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"

    var id: String { rawValue }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}
