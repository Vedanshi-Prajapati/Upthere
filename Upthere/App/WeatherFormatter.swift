import Foundation
import SwiftUI

@MainActor
struct WeatherFormatter: Sendable {
    let preferences: UnitPreferences

    init(preferences: UnitPreferences) {
        self.preferences = preferences
    }

    init() {
        self.preferences = UnitPreferences()
    }

    // MARK: - Temperature

    func temp(_ celsius: Double, unit: TemperatureUnit? = nil) -> String {
        let activeUnit = unit ?? preferences.temperatureUnit
        let converted = activeUnit.convert(celsius)
        let rounded = round(converted)
        // Guard against negative zero (-0°)
        let intVal = abs(rounded) < 0.001 ? 0 : Int(rounded)
        return "\(intVal)°"
    }

    func tempWithUnit(_ celsius: Double, unit: TemperatureUnit? = nil) -> String {
        let activeUnit = unit ?? preferences.temperatureUnit
        let converted = activeUnit.convert(celsius)
        let rounded = round(converted)
        let intVal = abs(rounded) < 0.001 ? 0 : Int(rounded)
        return "\(intVal)\(activeUnit.shortLabel)"
    }

    func tempValue(_ celsius: Double, unit: TemperatureUnit? = nil) -> Double {
        let activeUnit = unit ?? preferences.temperatureUnit
        return activeUnit.convert(celsius)
    }

    // MARK: - Wind Speed

    func wind(_ kmh: Double, unit: WindSpeedUnit? = nil) -> String {
        let activeUnit = unit ?? preferences.windSpeedUnit
        let converted = activeUnit.convert(kmh: max(0, kmh))
        let rounded = Int(round(converted))
        return "\(rounded) \(activeUnit.rawValue)"
    }

    // MARK: - Precipitation

    func precipitation(_ mm: Double, unit: PrecipitationUnit? = nil) -> String {
        let activeUnit = unit ?? preferences.precipitationUnit
        let converted = activeUnit.convert(mm: max(0, mm))
        switch activeUnit {
        case .mm:
            return String(format: "%.1f mm", converted)
        case .inches:
            return String(format: "%.2f in", converted)
        }
    }

    // MARK: - Pressure

    func pressure(_ hpa: Double) -> String {
        let valid = max(800.0, min(1100.0, hpa))
        return "\(Int(round(valid))) hPa"
    }

    // MARK: - Visibility

    func visibility(_ km: Double) -> String {
        let valid = max(0.0, km)
        let isMiles = (Locale.current.measurementSystem == .us || Locale.current.measurementSystem == .uk)
        if isMiles {
            let miles = valid * 0.621371
            return "\(Int(round(miles))) mi"
        } else {
            return "\(Int(round(valid))) km"
        }
    }
}

// MARK: - SwiftUI Environment

private struct WeatherFormatterKey: EnvironmentKey {
    static var defaultValue: WeatherFormatter {
        MainActor.assumeIsolated {
            WeatherFormatter()
        }
    }
}

extension EnvironmentValues {
    var weatherFormatter: WeatherFormatter {
        get { self[WeatherFormatterKey.self] }
        set { self[WeatherFormatterKey.self] = newValue }
    }
}
