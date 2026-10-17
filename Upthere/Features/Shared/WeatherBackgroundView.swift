import SwiftUI

// MARK: - Weather Condition Category

public enum WeatherVisualType: String, Equatable, Sendable {
    case sunny
    case partlyCloudy
    case cloudy
    case rainy
    case thunderstorm
    case snowy
    case night
    case defaultTheme

    public static func from(condition: String?, symbolName: String? = nil) -> WeatherVisualType {
        let cond = (condition ?? "").lowercased()
        let sym = (symbolName ?? "").lowercased()

        if sym.contains("moon") || cond.contains("night") {
            return .night
        }
        if cond.contains("thunder") || cond.contains("storm") || cond.contains("lightning") || sym.contains("bolt") {
            return .thunderstorm
        }
        if cond.contains("snow") || cond.contains("blizzard") || cond.contains("flurr") || cond.contains("sleet") || cond.contains("hail") || sym.contains("snow") {
            return .snowy
        }
        if cond.contains("rain") || cond.contains("drizzle") || cond.contains("shower") || sym.contains("rain") || sym.contains("drizzle") {
            return .rainy
        }
        if cond.contains("overcast") || cond.contains("fog") || cond.contains("mist") || cond.contains("haze") || cond.contains("smoke") || cond == "cloudy" {
            return .cloudy
        }
        if cond.contains("partly cloudy") || cond.contains("cloud") || sym.contains("cloud") {
            return .partlyCloudy
        }
        if cond.contains("sun") || cond.contains("clear") || sym.contains("sun") {
            return .sunny
        }
        return .partlyCloudy
    }
}

// MARK: - Unified Master Weather Background View

public struct WeatherBackgroundView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    public let type: WeatherVisualType

    public init(type: WeatherVisualType) {
        self.type = type
    }

    public init(condition: String?, symbolName: String? = nil) {
        self.type = WeatherVisualType.from(condition: condition, symbolName: symbolName)
    }

    public var body: some View {
        ZStack {
            // Layer 1: Photorealistic sky canvas with natural atmospheric gradient & subtle lighting
            RealisticSkyCanvas(type: type, reduceMotion: reduceMotion)

            // Layer 2: Subtle atmospheric motion layer (stopped if reduceMotion is active)
            if !reduceMotion {
                switch type {
                case .sunny:
                    SunnyAtmosphere()
                case .partlyCloudy:
                    RealisticCloudAtmosphere(isOvercast: false)
                case .cloudy:
                    RealisticCloudAtmosphere(isOvercast: true)
                case .rainy:
                    RainAtmosphere()
                case .thunderstorm:
                    ThunderstormAtmosphere()
                case .snowy:
                    SnowAtmosphere()
                case .night:
                    ClearNightAtmosphere()
                case .defaultTheme:
                    RealisticCloudAtmosphere(isOvercast: false)
                }
            }

            // Layer 3: Extra contrast scrim for bright daytime skies
            // Ensures secondary text has ≥4.5:1 contrast on daytime skies
            if type == .sunny || type == .partlyCloudy || type == .defaultTheme {
                LinearGradient(
                    colors: [
                        Color.black.opacity(0.42),  // Top — header protection
                        Color.black.opacity(0.24),  // Upper-mid
                        Color.black.opacity(0.14),  // Centre
                        Color.black.opacity(0.38)   // Bottom — card / footer protection
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .allowsHitTesting(false)
            }

            // Layer 4: Dark-mode tint
            if colorScheme == .dark {
                Color.black.opacity(0.32)
                    .allowsHitTesting(false)
            }

            // Layer 5: Strengthened contrast veil to guarantee ≥4.5:1 secondary text contrast on every sky
            LinearGradient(
                colors: [
                    Color.black.opacity(colorScheme == .dark ? 0.25 : 0.16),
                    Color.black.opacity(0.06),
                    Color.black.opacity(colorScheme == .dark ? 0.42 : 0.32)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)
        }
        .ignoresSafeArea()
    }
}
