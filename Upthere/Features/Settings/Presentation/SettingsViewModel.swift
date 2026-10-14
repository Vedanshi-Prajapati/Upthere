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
    public var weatherChangesEnabled: Bool = true {
        didSet { UserDefaults.standard.set(weatherChangesEnabled, forKey: "settings.weatherChangesEnabled") }
    }
    public var rainAlertsEnabled: Bool = true {
        didSet { UserDefaults.standard.set(rainAlertsEnabled, forKey: "settings.rainAlertsEnabled") }
    }
    public var severeAlertsEnabled: Bool = true {
        didSet { UserDefaults.standard.set(severeAlertsEnabled, forKey: "settings.severeAlertsEnabled") }
    }

    // MARK: - Location
    private let locationService: LocationService

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
        didSet { UserDefaults.standard.set(appearanceMode.rawValue, forKey: "settings.appearanceMode") }
    }
    public var textSize: TextSize {
        didSet { UserDefaults.standard.set(textSize.rawValue, forKey: "settings.textSize") }
    }

    // MARK: - About
    public let weatherDataProvider = "Apple WeatherKit"
    public let appVersion = "1.0 (24)"

    public init(locationService: LocationService? = nil) {
        self.locationService = locationService ?? .shared
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

        if UserDefaults.standard.object(forKey: "settings.weatherChangesEnabled") != nil {
            self.weatherChangesEnabled = UserDefaults.standard.bool(forKey: "settings.weatherChangesEnabled")
        }
        if UserDefaults.standard.object(forKey: "settings.rainAlertsEnabled") != nil {
            self.rainAlertsEnabled = UserDefaults.standard.bool(forKey: "settings.rainAlertsEnabled")
        }
        if UserDefaults.standard.object(forKey: "settings.severeAlertsEnabled") != nil {
            self.severeAlertsEnabled = UserDefaults.standard.bool(forKey: "settings.severeAlertsEnabled")
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

    public var scaleFactor: CGFloat {
        switch self {
        case .default_: return 1.0
        case .large:    return 1.15
        case .xl:       return 1.30
        case .ax:       return 1.50
        }
    }

    public var dynamicTypeSize: DynamicTypeSize {
        switch self {
        case .default_: return .large
        case .large:    return .xLarge
        case .xl:       return .xxLarge
        case .ax:       return .accessibility3
        }
    }
}
