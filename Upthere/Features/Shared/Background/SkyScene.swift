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

    public var gradientStops: (top: (r: Double, g: Double, b: Double), bottom: (r: Double, g: Double, b: Double)) {
        switch self {
        case .clearDay:
            return (
                top: (r: 0.08, g: 0.22, b: 0.50),
                bottom: (r: 0.14, g: 0.34, b: 0.60)
            )
        case .clearNight:
            return (
                top: (r: 0.02, g: 0.04, b: 0.12),
                bottom: (r: 0.05, g: 0.09, b: 0.22)
            )
        case .partlyCloudy(let isDay):
            if isDay {
                return (
                    top: (r: 0.09, g: 0.22, b: 0.46),
                    bottom: (r: 0.15, g: 0.32, b: 0.56)
                )
            } else {
                return (
                    top: (r: 0.03, g: 0.05, b: 0.14),
                    bottom: (r: 0.06, g: 0.10, b: 0.24)
                )
            }
        case .cloudy:
            return (
                top: (r: 0.12, g: 0.18, b: 0.26),
                bottom: (r: 0.18, g: 0.25, b: 0.36)
            )
        case .fog:
            return (
                top: (r: 0.16, g: 0.20, b: 0.25),
                bottom: (r: 0.22, g: 0.27, b: 0.33)
            )
        case .haze:
            return (
                top: (r: 0.20, g: 0.18, b: 0.16),
                bottom: (r: 0.26, g: 0.24, b: 0.21)
            )
        case .rain:
            return (
                top: (r: 0.08, g: 0.12, b: 0.20),
                bottom: (r: 0.13, g: 0.18, b: 0.27)
            )
        case .thunderstorm:
            return (
                top: (r: 0.04, g: 0.06, b: 0.12),
                bottom: (r: 0.08, g: 0.11, b: 0.19)
            )
        case .snow:
            return (
                top: (r: 0.10, g: 0.16, b: 0.25),
                bottom: (r: 0.16, g: 0.23, b: 0.34)
            )
        }
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
            return 40 // ~40 tiny dots (stars)
        case .clearDay:
            return 3  // 2-3 faint light rays (+ sun glow)
        case .partlyCloudy:
            return 4  // 3-6 blurred ellipse clouds
        case .cloudy:
            return 6  // 3-6 blurred ellipse clouds (denser)
        case .fog, .haze:
            return 3  // 2-3 wide soft horizontal bands
        case .rain, .thunderstorm:
            return 60 // ~60 thin falling diagonal lines
        case .snow:
            return 50 // ~50 slow dots
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
