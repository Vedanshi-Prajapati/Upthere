import Foundation
import Observation

public enum TemperatureUnit: String, CaseIterable, Identifiable, Sendable {
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

public enum WindSpeedUnit: String, CaseIterable, Identifiable, Sendable {
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

public enum PrecipitationUnit: String, CaseIterable, Identifiable, Sendable {
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

@Observable
@MainActor
public final class UnitPreferences: @unchecked Sendable {
    private let defaults: UserDefaults

    public var temperatureUnit: TemperatureUnit {
        didSet {
            defaults.set(temperatureUnit.rawValue, forKey: "settings.temperatureUnit")
        }
    }

    public var windSpeedUnit: WindSpeedUnit {
        didSet {
            defaults.set(windSpeedUnit.rawValue, forKey: "settings.windSpeedUnit")
        }
    }

    public var precipitationUnit: PrecipitationUnit {
        didSet {
            defaults.set(precipitationUnit.rawValue, forKey: "settings.precipitationUnit")
        }
    }

    public init(
        temperatureUnit: TemperatureUnit? = nil,
        windSpeedUnit: WindSpeedUnit? = nil,
        precipitationUnit: PrecipitationUnit? = nil,
        defaults: UserDefaults = AppGroup.defaults
    ) {
        self.defaults = defaults

        if let temperatureUnit {
            self.temperatureUnit = temperatureUnit
        } else if let raw = defaults.string(forKey: "settings.temperatureUnit"),
                  let unit = TemperatureUnit(rawValue: raw) {
            self.temperatureUnit = unit
        } else {
            self.temperatureUnit = .celsius
        }

        if let windSpeedUnit {
            self.windSpeedUnit = windSpeedUnit
        } else if let raw = defaults.string(forKey: "settings.windSpeedUnit"),
                  let unit = WindSpeedUnit(rawValue: raw) {
            self.windSpeedUnit = unit
        } else {
            self.windSpeedUnit = .kmh
        }

        if let precipitationUnit {
            self.precipitationUnit = precipitationUnit
        } else if let raw = defaults.string(forKey: "settings.precipitationUnit"),
                  let unit = PrecipitationUnit(rawValue: raw) {
            self.precipitationUnit = unit
        } else {
            self.precipitationUnit = .mm
        }
    }
}
