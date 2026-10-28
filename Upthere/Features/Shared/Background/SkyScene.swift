import SwiftUI
import Foundation

// MARK: - SkyScene

public enum SkyScene: Equatable, Hashable, Sendable {
    case clearDay
    case clearNight
    case partlyCloudy(isDaylight: Bool)
    case cloudy
    case fog
    case haze
    case rain
    case thunderstorm
    case snow

    public static let partlyCloudyDay = SkyScene.partlyCloudy(isDaylight: true)
    public static let partlyCloudyNight = SkyScene.partlyCloudy(isDaylight: false)

    public static func partlyCloudy(_ isDaylight: Bool = true) -> SkyScene {
        .partlyCloudy(isDaylight: isDaylight)
    }

    public var isDaylight: Bool {
        switch self {
        case .clearDay:
            return true
        case .clearNight:
            return false
        case .partlyCloudy(let isDay):
            return isDay
        case .cloudy, .fog, .haze, .rain, .thunderstorm, .snow:
            return true
        }
    }

    public var displayName: String {
        switch self {
        case .clearDay:
            return "Clear Day"
        case .clearNight:
            return "Clear Night"
        case .partlyCloudy(let isDay):
            return isDay ? "Partly Cloudy (Day)" : "Partly Cloudy (Night)"
        case .cloudy:
            return "Cloudy"
        case .fog:
            return "Fog"
        case .haze:
            return "Haze"
        case .rain:
            return "Rain"
        case .thunderstorm:
            return "Thunderstorm"
        case .snow:
            return "Snow"
        }
    }

    // MARK: - Pure Mapping Function

    public static func from(condition: String?, isDaylight: Bool) -> SkyScene {
        guard let condition = condition?.trimmingCharacters(in: .whitespacesAndNewlines), !condition.isEmpty else {
            return isDaylight ? .clearDay : .clearNight
        }
        let cond = condition.lowercased()

        // 1. Thunderstorm / Storms
        if cond.contains("thunder") || cond.contains("lightning") || cond.contains("storm") || cond.contains("tornado") || cond.contains("hurricane") {
            return .thunderstorm
        }

        // 2. Snow / Winter Weather
        if cond.contains("snow") || cond.contains("blizzard") || cond.contains("flurr") || cond.contains("sleet") || cond.contains("hail") || cond.contains("wintry") || cond.contains("frigid") {
            return .snow
        }

        // 3. Rain / Showers / Drizzle
        if cond.contains("rain") || cond.contains("drizzle") || cond.contains("shower") {
            return .rain
        }

        // 4. Fog / Mist
        if cond.contains("fog") || cond.contains("mist") {
            return .fog
        }

        // 5. Haze / Smoke / Dust
        if cond.contains("haz") || cond.contains("smok") || cond.contains("dust") || cond.contains("sand") {
            return .haze
        }

        // 6. Mostly Clear / Clear
        if cond == "mostly clear" || cond.contains("mostly clear") {
            return isDaylight ? .clearDay : .clearNight
        }

        // 7. Overcast / Cloudy (Dense)
        if cond.contains("overcast") || cond == "cloudy" || cond == "cloud" {
            return .cloudy
        }

        // 8. Partly / Mostly Cloudy / Breezy
        if cond.contains("partly") || cond.contains("mostly") || cond.contains("scattered") || cond.contains("cloud") || cond.contains("wind") || cond.contains("breez") {
            return .partlyCloudy(isDaylight: isDaylight)
        }

        // 9. Clear / Sunny / Hot / Fair
        if cond.contains("clear") || cond.contains("sun") || cond.contains("hot") || cond.contains("fair") {
            return isDaylight ? .clearDay : .clearNight
        }

        return isDaylight ? .clearDay : .clearNight
    }

    public static func from(condition: String?, symbolName: String? = nil, isDaylight: Bool? = nil) -> SkyScene {
        let daylight: Bool
        if let isDaylight = isDaylight {
            daylight = isDaylight
        } else if let sym = symbolName?.lowercased() {
            daylight = !sym.contains("moon")
        } else {
            daylight = true
        }
        return from(condition: condition, isDaylight: daylight)
    }

    // MARK: - Debug Launch Flag Override

    public static var debugOverride: SkyScene? {
        #if DEBUG
        if let idx = ProcessInfo.processInfo.arguments.firstIndex(of: "-skyScene"),
           idx + 1 < ProcessInfo.processInfo.arguments.count {
            let name = ProcessInfo.processInfo.arguments[idx + 1].lowercased()
            switch name {
            case "clearday", "clear_day", "day":
                return .clearDay
            case "clearnight", "clear_night", "night":
                return .clearNight
            case "partlycloudyday", "partlycloudy_day", "partlycloudy":
                return .partlyCloudy(isDaylight: true)
            case "partlycloudynight", "partlycloudy_night":
                return .partlyCloudy(isDaylight: false)
            case "cloudy", "overcast":
                return .cloudy
            case "fog", "foggy":
                return .fog
            case "haze", "hazy":
                return .haze
            case "rain", "rainy":
                return .rain
            case "thunderstorm", "storm":
                return .thunderstorm
            case "snow", "snowy":
                return .snow
            default:
                return nil
            }
        }
        #endif
        return nil
    }

    // MARK: - Gradients (Vertical Stop RGBs & Colors)

    // MARK: - Hex Converter Helper

    public static func hexToRGB(_ hex: String) -> (r: Double, g: Double, b: Double) {
        let clean = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: clean).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255.0
        let g = Double((int >> 8) & 0xFF) / 255.0
        let b = Double(int & 0xFF) / 255.0
        return (r, g, b)
    }

    // MARK: - Gradient Hex Stops

    public var gradientHex: (top: String, bottom: String) {
        switch self {
        case .clearDay:
            return ("#1F4F78", "#3E7396")
        case .clearNight:
            return ("#080F25", "#182641")
        case .partlyCloudy(let isDay):
            return isDay ? ("#3D5366", "#667784") : ("#080F25", "#182641")
        case .cloudy:
            return ("#3D5366", "#667784")
        case .fog, .haze:
            return ("#405E61", "#647676")
        case .rain, .thunderstorm:
            return ("#243748", "#465D70")
        case .snow:
            return ("#40576D", "#637788")
        }
    }

    public var gradientStops: (top: (r: Double, g: Double, b: Double), bottom: (r: Double, g: Double, b: Double)) {
        let hex = gradientHex
        return (top: SkyScene.hexToRGB(hex.top), bottom: SkyScene.hexToRGB(hex.bottom))
    }

    public var colors: [Color] {
        let (top, bottom) = gradientStops
        return [
            Color(red: top.r, green: top.g, blue: top.b),
            Color(red: bottom.r, green: bottom.g, blue: bottom.b)
        ]
    }

    // MARK: - Expected Particle Counts

    public var expectedParticleCount: Int {
        switch self {
        case .clearNight:
            return 40 // 40 stars
        case .clearDay:
            return 2  // 2 rays
        case .partlyCloudy:
            return 3  // 3 clouds
        case .cloudy:
            return 5  // 5 clouds
        case .fog, .haze:
            return 3  // 3 bands
        case .rain, .thunderstorm:
            return 60 // 60 streaks
        case .snow:
            return 50 // 50 dots
        }
    }
}

// MARK: - CaseIterable Conformance

extension SkyScene: CaseIterable {
    public static var allCases: [SkyScene] {
        [
            .clearDay,
            .clearNight,
            .partlyCloudy(isDaylight: true),
            .partlyCloudy(isDaylight: false),
            .cloudy,
            .fog,
            .haze,
            .rain,
            .thunderstorm,
            .snow
        ]
    }
}

// MARK: - Weather Extension

extension Weather {
    public var skyScene: SkyScene {
        SkyScene.from(condition: condition, isDaylight: isDaylight)
    }
}
