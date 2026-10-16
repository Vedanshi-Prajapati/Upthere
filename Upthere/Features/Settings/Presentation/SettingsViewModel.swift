import Foundation
import Observation
import WidgetKit

@Observable
@MainActor
public final class SettingsViewModel {
    // MARK: - Weather Units
    public var temperatureUnit: TemperatureUnit {
        didSet { defaults.set(temperatureUnit.rawValue, forKey: "settings.temperatureUnit") }
    }
    public var windSpeedUnit: WindSpeedUnit {
        didSet { defaults.set(windSpeedUnit.rawValue, forKey: "settings.windSpeedUnit") }
    }
    public var precipitationUnit: PrecipitationUnit {
        didSet { defaults.set(precipitationUnit.rawValue, forKey: "settings.precipitationUnit") }
    }

    // MARK: - Notifications
    public var weatherChangesEnabled: Bool = true {
        didSet { defaults.set(weatherChangesEnabled, forKey: "settings.weatherChangesEnabled") }
    }
    public var rainAlertsEnabled: Bool = true {
        didSet { defaults.set(rainAlertsEnabled, forKey: "settings.rainAlertsEnabled") }
    }
    public var severeAlertsEnabled: Bool = true {
        didSet {
            defaults.set(severeAlertsEnabled, forKey: AppGroup.severeAlertsKey)
            WidgetCenter.shared.reloadAllTimelines()
            if #available(iOS 18.0, *) {
                ControlCenter.shared.reloadAllControls()
            }
        }
    }

    // MARK: - Location
    private let locationService: LocationService
    private let defaults: UserDefaults

    public var currentLocationName: String {
        if locationService.isAuthorized {
            return locationService.currentCityName
        } else if locationService.authorizationStatus == .notDetermined {
            return "Not Determined"
        } else {
            return "Permission Denied"
        }
    }
    public var locationPermission: String {
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
    public var appearanceMode: AppearanceMode {
        didSet { defaults.set(appearanceMode.rawValue, forKey: "settings.appearanceMode") }
    }

    // MARK: - About
    public let weatherDataProvider = "Apple WeatherKit"
    public let appVersion = "1.0 (24)"

    public init(locationService: LocationService? = nil, defaults: UserDefaults = AppGroup.defaults) {
        self.locationService = locationService ?? .shared
        self.defaults = defaults
        AppGroup.migrateSettingsIfNeeded(standard: .standard, group: defaults)

        if let rawTemp = defaults.string(forKey: "settings.temperatureUnit"),
           let unit = TemperatureUnit(rawValue: rawTemp) {
            self.temperatureUnit = unit
        } else {
            self.temperatureUnit = .celsius
        }

        if let rawWind = defaults.string(forKey: "settings.windSpeedUnit"),
           let unit = WindSpeedUnit(rawValue: rawWind) {
            self.windSpeedUnit = unit
        } else {
            self.windSpeedUnit = .kmh
        }

        if let rawPrecip = defaults.string(forKey: "settings.precipitationUnit"),
           let unit = PrecipitationUnit(rawValue: rawPrecip) {
            self.precipitationUnit = unit
        } else {
            self.precipitationUnit = .mm
        }

        if let rawApp = defaults.string(forKey: "settings.appearanceMode"),
           let mode = AppearanceMode(rawValue: rawApp) {
            self.appearanceMode = mode
        } else {
            self.appearanceMode = .system
        }

        if defaults.object(forKey: "settings.weatherChangesEnabled") != nil {
            self.weatherChangesEnabled = defaults.bool(forKey: "settings.weatherChangesEnabled")
        }
        if defaults.object(forKey: "settings.rainAlertsEnabled") != nil {
            self.rainAlertsEnabled = defaults.bool(forKey: "settings.rainAlertsEnabled")
        }
        if defaults.object(forKey: AppGroup.severeAlertsKey) != nil {
            self.severeAlertsEnabled = defaults.bool(forKey: AppGroup.severeAlertsKey)
        }
    }

    // MARK: - Helpers

    public func formatTemp(_ celsius: Double) -> String {
        let val = temperatureUnit.convert(celsius)
        return "\(Int(round(val)))°"
    }

    public func formatWind(_ kmh: Double) -> String {
        let val = windSpeedUnit.convert(kmh: kmh)
        return "\(Int(round(val))) \(windSpeedUnit.rawValue)"
    }
}

// MARK: - Enums

import Foundation
import Observation
import SwiftUI

public enum TemperatureUnit: String, CaseIterable, Identifiable {
    case celsius = "Celsius (°C)"
    case fahrenheit = "Fahrenheit (°F)"

    public var id: String { rawValue }

    public var shortLabel: String {
        switch self {
        case .celsius: return "°C"
        case .fahrenheit: return "°F"
        }
    }

    public func convert(_ celsius: Double) -> Double {
        switch self {
        case .celsius: return celsius
        case .fahrenheit: return (celsius * 9 / 5) + 32
        }
    }
}

public enum WindSpeedUnit: String, CaseIterable, Identifiable {
    case kmh = "km/h"
    case mph = "mph"
    case ms = "m/s"

    public var id: String { rawValue }

    public func convert(kmh: Double) -> Double {
        switch self {
        case .kmh: return kmh
        case .mph: return kmh * 0.621371
        case .ms: return kmh / 3.6
        }
    }
}

public enum PrecipitationUnit: String, CaseIterable, Identifiable {
    case mm = "mm"
    case inches = "in"

    public var id: String { rawValue }

    public func convert(mm: Double) -> Double {
        switch self {
        case .mm: return mm
        case .inches: return mm * 0.0393701
        }
    }
}

public enum AppearanceMode: String, CaseIterable, Identifiable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"

    public var id: String { rawValue }

    public var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}
