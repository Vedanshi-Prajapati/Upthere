import Foundation
import Observation

@Observable
@MainActor
public final class SettingsViewModel {
    // MARK: - Weather Units
    public var temperatureUnit: TemperatureUnit = .celsius
    public var windSpeedUnit: WindSpeedUnit = .kmh
    public var precipitationUnit: PrecipitationUnit = .mm

    // MARK: - Notifications
    public var weatherChangesEnabled: Bool = true
    public var rainAlertsEnabled: Bool = true
    public var severeWeatherAlertsEnabled: Bool = true

    // MARK: - Location
    public var currentLocationName: String = "Ghaziabad"
    public var locationPermission: String = "While Using"

    // MARK: - Appearance
    public var appearanceMode: AppearanceMode = .light
    public var textSize: TextSize = .default_

    // MARK: - Prototype states
    public var offlineWithCachedData: Bool = false
    public var rightToLeftLayout: Bool = false
    public var tabletMode: Bool = false
    public var smallestDevice: Bool = false

    // MARK: - About
    public let weatherDataProvider = "Apple WeatherKit"
    public let appVersion = "1.0 (24)"

    public init() {}
}

// MARK: - Enums

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
}

public enum WindSpeedUnit: String, CaseIterable, Identifiable {
    case kmh = "km/h"
    case mph = "mph"
    case ms = "m/s"

    public var id: String { rawValue }
}

public enum PrecipitationUnit: String, CaseIterable, Identifiable {
    case mm = "mm"
    case inches = "in"

    public var id: String { rawValue }
}

public enum AppearanceMode: String, CaseIterable, Identifiable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"

    public var id: String { rawValue }
}

public enum TextSize: String, CaseIterable, Identifiable {
    case default_ = "Default"
    case large = "Large"
    case xl = "XL"
    case ax = "AX"

    public var id: String { rawValue }
}
