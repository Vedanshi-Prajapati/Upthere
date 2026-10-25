import Foundation
import Observation

enum TemperatureUnit: String, CaseIterable, Identifiable, Sendable {
    case celsius = "Celsius (°C)"
    case fahrenheit = "Fahrenheit (°F)"

    var id: String { rawValue }

    var shortLabel: String {
        switch self {
        case .celsius: return "°C"
        case .fahrenheit: return "°F"
        }
    }

    func convert(_ celsius: Double) -> Double {
        switch self {
        case .celsius: return celsius
        case .fahrenheit: return (celsius * 9 / 5) + 32
        }
    }
}

enum WindSpeedUnit: String, CaseIterable, Identifiable, Sendable {
    case kmh = "km/h"
    case mph = "mph"
    case ms = "m/s"

    var id: String { rawValue }

    func convert(kmh: Double) -> Double {
        switch self {
        case .kmh: return kmh
        case .mph: return kmh * 0.621371
        case .ms: return kmh / 3.6
        }
    }
}

enum PrecipitationUnit: String, CaseIterable, Identifiable, Sendable {
    case mm = "mm"
    case inches = "in"

    var id: String { rawValue }

    func convert(mm: Double) -> Double {
        switch self {
        case .mm: return mm
        case .inches: return mm * 0.0393701
        }
    }
}

@Observable
@MainActor
final class UnitPreferences: @unchecked Sendable {
    private let defaults: UserDefaults

    var temperatureUnit: TemperatureUnit {
        didSet {
            defaults.set(temperatureUnit.rawValue, forKey: "settings.temperatureUnit")
        }
    }

    var windSpeedUnit: WindSpeedUnit {
        didSet {
            defaults.set(windSpeedUnit.rawValue, forKey: "settings.windSpeedUnit")
        }
    }

    var precipitationUnit: PrecipitationUnit {
        didSet {
            defaults.set(precipitationUnit.rawValue, forKey: "settings.precipitationUnit")
        }
    }

    init(
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
