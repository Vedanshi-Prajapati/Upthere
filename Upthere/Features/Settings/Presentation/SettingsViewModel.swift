import Foundation
import Observation

@Observable
@MainActor
public final class SettingsViewModel {
    // MARK: - Weather Units
    public var temperatureUnit: TemperatureUnit {
        didSet { UserDefaults.standard.set(temperatureUnit.rawValue, forKey: "settings.temperatureUnit") }
    }
    public var windSpeedUnit: WindSpeedUnit {
        didSet { UserDefaults.standard.set(windSpeedUnit.rawValue, forKey: "settings.windSpeedUnit") }
    }
    public var precipitationUnit: PrecipitationUnit {
        didSet { UserDefaults.standard.set(precipitationUnit.rawValue, forKey: "settings.precipitationUnit") }
    }

    // MARK: - Notifications
    public var weatherChangesEnabled: Bool = true
    public var rainAlertsEnabled: Bool = true

    // MARK: - Location
    public var currentLocationName: String {
        LocationService.shared.currentCityName
    }
    public var locationPermission: String {
        switch LocationService.shared.authorizationStatus {
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
        didSet { UserDefaults.standard.set(appearanceMode.rawValue, forKey: "settings.appearanceMode") }
    }
    public var textSize: TextSize {
        didSet { UserDefaults.standard.set(textSize.rawValue, forKey: "settings.textSize") }
    }

    // MARK: - About
    public let weatherDataProvider = "Apple WeatherKit"
    public let appVersion = "1.0 (24)"

    public init() {
        if let rawTemp = UserDefaults.standard.string(forKey: "settings.temperatureUnit"),
           let unit = TemperatureUnit(rawValue: rawTemp) {
            self.temperatureUnit = unit
        } else {
            self.temperatureUnit = .celsius
        }

        if let rawWind = UserDefaults.standard.string(forKey: "settings.windSpeedUnit"),
           let unit = WindSpeedUnit(rawValue: rawWind) {
            self.windSpeedUnit = unit
        } else {
            self.windSpeedUnit = .kmh
        }

        if let rawPrecip = UserDefaults.standard.string(forKey: "settings.precipitationUnit"),
           let unit = PrecipitationUnit(rawValue: rawPrecip) {
            self.precipitationUnit = unit
        } else {
            self.precipitationUnit = .mm
        }

        if let rawApp = UserDefaults.standard.string(forKey: "settings.appearanceMode"),
           let mode = AppearanceMode(rawValue: rawApp) {
            self.appearanceMode = mode
        } else {
            self.appearanceMode = .system
        }

        if let rawText = UserDefaults.standard.string(forKey: "settings.textSize"),
           let size = TextSize(rawValue: rawText) {
            self.textSize = size
        } else {
            self.textSize = .default_
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

public enum TextSize: String, CaseIterable, Identifiable {
    case default_ = "Default"
    case large = "Large"
    case xl = "XL"
    case ax = "AX"

    public var id: String { rawValue }

    public var dynamicTypeSize: DynamicTypeSize {
        switch self {
        case .default_: return .large
        case .large:    return .xLarge
        case .xl:       return .xxLarge
        case .ax:       return .accessibility3
        }
    }
}
