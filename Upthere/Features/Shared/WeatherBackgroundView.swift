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
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    public let type: WeatherVisualType

    public init(type: WeatherVisualType) {
        self.type = type
    }

    public init(condition: String?, symbolName: String? = nil) {
        self.type = WeatherVisualType.from(condition: condition, symbolName: symbolName)
    }

    @Environment(\.isWeatherAnimationPaused) private var isPaused

    public var body: some View {
        ZStack {
            // Layer 1: Photorealistic sky canvas with natural atmospheric gradient & subtle lighting
            RealisticSkyCanvas(type: type, reduceMotion: reduceMotion)

            // Layer 2: Subtle atmospheric motion layer (stopped if reduceMotion is active or paused)
            if !reduceMotion && !isPaused {
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

            // Static background layers (Layers 3, 4, 5, 6) wrapped in .drawingGroup() to avoid re-blurring
            StaticScrimLayer(
                type: type,
                colorScheme: colorScheme,
                colorSchemeContrast: colorSchemeContrast
            )
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

// MARK: - Static Scrim Layer
private struct StaticScrimLayer: View {
    let type: WeatherVisualType
    let colorScheme: ColorScheme
    let colorSchemeContrast: ColorSchemeContrast

    var body: some View {
        ZStack {
            // Layer 3: Extra contrast scrim for bright daytime skies (Snow, Fog, Clear Day)
            if type == .snowy || type == .cloudy {
                LinearGradient(
                    colors: [
                        Color.black.opacity(0.55),
                        Color.black.opacity(0.44),
                        Color.black.opacity(0.35),
                        Color.black.opacity(0.50)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            } else if type == .sunny || type == .partlyCloudy || type == .defaultTheme {
                LinearGradient(
                    colors: [
                        Color.black.opacity(0.44),
                        Color.black.opacity(0.28),
                        Color.black.opacity(0.18),
                        Color.black.opacity(0.40)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            } else if type == .rainy {
                LinearGradient(
                    colors: [
                        Color.black.opacity(0.36),
                        Color.black.opacity(0.22),
                        Color.black.opacity(0.16),
                        Color.black.opacity(0.35)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }

            // Layer 4: Dark-mode tint
            if colorScheme == .dark {
                Color.black.opacity(0.32)
            }

            // Layer 5: Strengthened contrast veil
            LinearGradient(
                colors: [
                    Color.black.opacity(colorScheme == .dark ? 0.28 : 0.20),
                    Color.black.opacity(0.08),
                    Color.black.opacity(colorScheme == .dark ? 0.44 : 0.36)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            // Layer 6: Increased contrast boost for system accessibility settings
            if colorSchemeContrast == .increased {
                Color.black.opacity(0.22)
            }
        }
        .allowsHitTesting(false)
        .drawingGroup()
    }
}
