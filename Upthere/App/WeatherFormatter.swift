import Foundation
import Observation

@Observable
@MainActor
public final class WeatherFormatter {
    public static let shared = WeatherFormatter()

    public init() {}

    // MARK: - Temperature

    public func temp(_ celsius: Double, unit: TemperatureUnit? = nil) -> String {
        let activeUnit = unit ?? currentTemperatureUnit
        let converted = activeUnit.convert(celsius)
        let rounded = round(converted)
        // Guard against negative zero (-0°)
        let intVal = abs(rounded) < 0.001 ? 0 : Int(rounded)
        return "\(intVal)°"
    }

    public func tempWithUnit(_ celsius: Double, unit: TemperatureUnit? = nil) -> String {
        let activeUnit = unit ?? currentTemperatureUnit
        let converted = activeUnit.convert(celsius)
        let rounded = round(converted)
        let intVal = abs(rounded) < 0.001 ? 0 : Int(rounded)
        return "\(intVal)\(activeUnit.shortLabel)"
    }

    public func tempValue(_ celsius: Double, unit: TemperatureUnit? = nil) -> Double {
        let activeUnit = unit ?? currentTemperatureUnit
        return activeUnit.convert(celsius)
    }

    // MARK: - Wind Speed

    public func wind(_ kmh: Double, unit: WindSpeedUnit? = nil) -> String {
        let activeUnit = unit ?? currentWindUnit
        let converted = activeUnit.convert(kmh: max(0, kmh))
        let rounded = Int(round(converted))
        return "\(rounded) \(activeUnit.rawValue)"
    }

    // MARK: - Precipitation

    public func precipitation(_ mm: Double, unit: PrecipitationUnit? = nil) -> String {
        let activeUnit = unit ?? currentPrecipitationUnit
        let converted = activeUnit.convert(mm: max(0, mm))
        switch activeUnit {
        case .mm:
            return String(format: "%.1f mm", converted)
        case .inches:
            return String(format: "%.2f in", converted)
        }
    }

    // MARK: - Pressure

    public func pressure(_ hpa: Double) -> String {
        let valid = max(800.0, min(1100.0, hpa))
        return "\(Int(round(valid))) hPa"
    }

    // MARK: - Visibility

    public func visibility(_ km: Double) -> String {
        let valid = max(0.0, km)
        let isMiles = (Locale.current.measurementSystem == .us || Locale.current.measurementSystem == .uk)
        if isMiles {
            let miles = valid * 0.621371
            return "\(Int(round(miles))) mi"
        } else {
            return "\(Int(round(valid))) km"
        }
    }

    // MARK: - Private Helpers

    private var currentTemperatureUnit: TemperatureUnit {
        if let raw = UserDefaults.standard.string(forKey: "settings.temperatureUnit"),
           let unit = TemperatureUnit(rawValue: raw) {
            return unit
        }
        return .celsius
    }

    private var currentWindUnit: WindSpeedUnit {
        if let raw = UserDefaults.standard.string(forKey: "settings.windSpeedUnit"),
           let unit = WindSpeedUnit(rawValue: raw) {
            return unit
        }
        return .kmh
    }

    private var currentPrecipitationUnit: PrecipitationUnit {
        if let raw = UserDefaults.standard.string(forKey: "settings.precipitationUnit"),
           let unit = PrecipitationUnit(rawValue: raw) {
            return unit
        }
        return .mm
    }
}
