import SwiftUI

// MARK: - Weather Illustration Type

public enum WeatherIllustrationType: String, Equatable, Sendable {
    case clearDay
    case clearNight
    case partlyCloudyDay
    case partlyCloudyNight
    case cloudy
    case rainy
    case heavyRain
    case thunderstorm
    case snowy
    case windy
    case foggy

    public static func from(condition: String?, symbolName: String? = nil) -> WeatherIllustrationType {
        let cond = (condition ?? "").lowercased()
        let sym = (symbolName ?? "").lowercased()

        let isNight = sym.contains("moon") || cond.contains("night")

        if cond.contains("thunder") || cond.contains("storm") || cond.contains("lightning") || sym.contains("bolt") {
            return .thunderstorm
        }
        if cond.contains("snow") || cond.contains("blizzard") || cond.contains("sleet") || cond.contains("flurr") || cond.contains("hail") || sym.contains("snow") {
            return .snowy
        }
        if cond.contains("heavy rain") || sym.contains("heavyrain") {
            return .heavyRain
        }
        if cond.contains("rain") || cond.contains("drizzle") || cond.contains("shower") || sym.contains("rain") || sym.contains("drizzle") {
            return .rainy
        }
        if cond.contains("wind") || cond.contains("breeze") || cond.contains("gale") || sym.contains("wind") {
            return .windy
        }
        if cond.contains("fog") || cond.contains("mist") || cond.contains("haze") || cond.contains("smoke") || sym.contains("fog") {
            return .foggy
        }
        if isNight {
            if cond.contains("cloud") || sym.contains("cloud") {
                return .partlyCloudyNight
            }
            return .clearNight
        }
        if cond.contains("partly cloudy") || (sym.contains("cloud") && (sym.contains("sun") || cond.contains("sun"))) {
            return .partlyCloudyDay
        }
        if cond.contains("cloud") || cond.contains("overcast") || sym.contains("cloud") {
            return .cloudy
        }
        if cond.contains("sun") || cond.contains("clear") || sym.contains("sun") {
            return .clearDay
        }
        return .partlyCloudyDay
    }
}

// MARK: - Master WeatherIllustrationView

public struct WeatherIllustrationView: View {
    public let type: WeatherIllustrationType
    public let size: CGFloat
    public let animated: Bool

    public init(
        type: WeatherIllustrationType,
        size: CGFloat = 80,
        animated: Bool = true
    ) {
        self.type = type
        self.size = size
        self.animated = animated
    }

    public init(
        condition: String?,
        symbolName: String? = nil,
        size: CGFloat = 80,
        animated: Bool = true
    ) {
        self.type = WeatherIllustrationType.from(condition: condition, symbolName: symbolName)
        self.size = size
        self.animated = animated
    }

    public var body: some View {
        Group {
            if animated {
                TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { context in
                    illustrationContent(time: context.date.timeIntervalSinceReferenceDate)
                }
            } else {
                illustrationContent(time: 0)
            }
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabelText)
    }

    @ViewBuilder
    private func illustrationContent(time: TimeInterval) -> some View {
        switch type {
        case .clearDay:
            ClearDayIllustration(size: size, time: time, animated: animated)
        case .clearNight:
            ClearNightIllustration(size: size, time: time, animated: animated)
        case .partlyCloudyDay:
            PartlyCloudyDayIllustration(size: size, time: time, animated: animated)
        case .partlyCloudyNight:
            PartlyCloudyNightIllustration(size: size, time: time, animated: animated)
        case .cloudy:
            CloudyIllustration(size: size, time: time, animated: animated)
        case .rainy:
            RainyIllustration(isHeavy: false, size: size, time: time, animated: animated)
        case .heavyRain:
            RainyIllustration(isHeavy: true, size: size, time: time, animated: animated)
        case .thunderstorm:
            ThunderstormIllustration(size: size, time: time, animated: animated)
        case .snowy:
            SnowyIllustration(size: size, time: time, animated: animated)
        case .windy:
            WindyIllustration(size: size, time: time, animated: animated)
        case .foggy:
            FoggyIllustration(size: size, time: time, animated: animated)
        }
    }

    private var accessibilityLabelText: String {
        switch type {
        case .clearDay: return "Sunny"
        case .clearNight: return "Clear Night"
        case .partlyCloudyDay: return "Partly Cloudy"
        case .partlyCloudyNight: return "Partly Cloudy Night"
        case .cloudy: return "Cloudy"
        case .rainy: return "Rainy"
        case .heavyRain: return "Heavy Rain"
        case .thunderstorm: return "Thunderstorm"
        case .snowy: return "Snowy"
        case .windy: return "Windy"
        case .foggy: return "Foggy"
        }
    }
}

// MARK: - 1. Clear Day Graphic (Radiant Sun with Corona Rays & Solar Glow)

private struct ClearDayIllustration: View {
    let size: CGFloat
    let time: TimeInterval
    let animated: Bool

    var body: some View {
        let pulse = animated ? sin(time * 1.8) * 0.04 : 0.0
        let rayAngle = animated ? (time * 12.0).truncatingRemainder(dividingBy: 360.0) : 0.0

        ZStack {
            // Ambient solar bloom
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 1.0, green: 0.82, blue: 0.25).opacity(0.50),
                            Color(red: 1.0, green: 0.55, blue: 0.12).opacity(0.18),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: size * 0.08,
                        endRadius: size * 0.48
                    )
                )
                .frame(width: size, height: size)
                .scaleEffect(1.0 + pulse)

            // Radiant corona rays
            SunRaysView(size: size * 0.88)
                .rotationEffect(.degrees(rayAngle))

            // Core sun sphere with rich multi-stop gradient
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 1.0, green: 0.94, blue: 0.50), // Pure luminous gold
                                Color(red: 1.0, green: 0.68, blue: 0.15), // Warm solar amber
                                Color(red: 0.96, green: 0.40, blue: 0.08)  // Sunset rim
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: size * 0.54, height: size * 0.54)
                    .shadow(color: Color(red: 1.0, green: 0.6, blue: 0.1).opacity(0.65), radius: size * 0.10, x: 0, y: size * 0.04)

                // 3D Glass specular gloss arc
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.85),
                                Color.white.opacity(0.20),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: max(1.5, size * 0.035)
                    )
                    .frame(width: size * 0.46, height: size * 0.46)
                    .offset(x: -size * 0.015, y: -size * 0.015)
            }
            .scaleEffect(1.0 + pulse * 0.6)
        }
    }
}

// MARK: - 2. Clear Night Graphic (Luminous Crescent Moon & Twinkling 4-Point Stars)

private struct ClearNightIllustration: View {
    let size: CGFloat
    let time: TimeInterval
    let animated: Bool

    var body: some View {
        let moonFloat = animated ? sin(time * 1.5) * (size * 0.02) : 0.0
        let s1Pulse = animated ? (sin(time * 2.8) + 1.0) * 0.5 : 0.8
        let s2Pulse = animated ? (sin(time * 3.4 + 1.2) + 1.0) * 0.5 : 0.7
        let s3Pulse = animated ? (sin(time * 2.2 + 2.5) + 1.0) * 0.5 : 0.9

        ZStack {
            // Celestial moonlight aura
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.65, green: 0.80, blue: 1.0).opacity(0.38),
                            Color(red: 0.45, green: 0.55, blue: 0.95).opacity(0.12),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: size * 0.12,
                        endRadius: size * 0.48
                    )
                )
                .frame(width: size, height: size)

            // Sparkle Star 1 (Top right)
            SparkleStarShape()
                .fill(
                    LinearGradient(
                        colors: [Color.white, Color(red: 0.82, green: 0.92, blue: 1.0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: size * 0.22, height: size * 0.22)
                .shadow(color: Color(red: 0.7, green: 0.85, blue: 1.0).opacity(0.85), radius: size * 0.05)
                .position(x: size * 0.82, y: size * 0.24)
                .scaleEffect(0.65 + s1Pulse * 0.5)
                .opacity(0.40 + s1Pulse * 0.60)

            // Sparkle Star 2 (Far right middle)
            SparkleStarShape()
                .fill(Color.white)
                .frame(width: size * 0.15, height: size * 0.15)
                .shadow(color: Color.white.opacity(0.75), radius: size * 0.035)
                .position(x: size * 0.90, y: size * 0.56)
                .scaleEffect(0.60 + s2Pulse * 0.5)
                .opacity(0.35 + s2Pulse * 0.65)

            // Sparkle Star 3 (Lower center subtle twinkle)
            SparkleStarShape()
                .fill(Color(red: 0.88, green: 0.94, blue: 1.0))
                .frame(width: size * 0.12, height: size * 0.12)
                .position(x: size * 0.60, y: size * 0.84)
                .scaleEffect(0.55 + s3Pulse * 0.5)
                .opacity(0.30 + s3Pulse * 0.70)

            // Crescent Moon Body
            ZStack {
                CrescentMoonShape()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 1.0, green: 0.98, blue: 0.90),  // Pale moonlight ivory
                                Color(red: 0.92, green: 0.94, blue: 0.98),  // Soft silver cream
                                Color(red: 0.75, green: 0.84, blue: 0.98)   // Celestial blue-silver rim
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: size * 0.64, height: size * 0.64)
                    .shadow(color: Color(red: 0.65, green: 0.80, blue: 1.0).opacity(0.55), radius: size * 0.09, x: -size * 0.01, y: size * 0.02)

                // Outer crescent specular edge
                CrescentMoonShape()
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.95),
                                Color.white.opacity(0.20)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: max(1.2, size * 0.025)
                    )
                    .frame(width: size * 0.64, height: size * 0.64)
            }
            .offset(x: -size * 0.05, y: moonFloat)
        }
    }
}

// MARK: - 3. Partly Cloudy Day Graphic

private struct PartlyCloudyDayIllustration: View {
    let size: CGFloat
    let time: TimeInterval
    let animated: Bool

    var body: some View {
        let sunPulse = animated ? sin(time * 2.0) * 0.04 : 0.0
        let cloudFloat = animated ? sin(time * 1.6) * (size * 0.015) : 0.0

        ZStack {
            // Sun in upper right
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(red: 1.0, green: 0.85, blue: 0.3).opacity(0.55),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: size * 0.06,
                            endRadius: size * 0.28
                        )
                    )
                    .frame(width: size * 0.58, height: size * 0.58)

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 1.0, green: 0.93, blue: 0.45),
                                Color(red: 1.0, green: 0.65, blue: 0.15),
                                Color(red: 0.98, green: 0.42, blue: 0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: size * 0.44, height: size * 0.44)
                    .shadow(color: Color(red: 1.0, green: 0.6, blue: 0.15).opacity(0.6), radius: size * 0.08)
            }
            .scaleEffect(1.0 + sunPulse)
            .offset(x: size * 0.18, y: -size * 0.16)

            // Back atmospheric shadow cloud
            VolumetricCloudShape()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.72, green: 0.80, blue: 0.92),
                            Color(red: 0.55, green: 0.65, blue: 0.80)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: size * 0.74, height: size * 0.48)
                .offset(x: -size * 0.12, y: size * 0.10)
                .opacity(0.65)

            // Front luminous fluffy cloud
            ZStack {
                VolumetricCloudShape()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white,
                                Color(red: 0.92, green: 0.95, blue: 0.99),
                                Color(red: 0.80, green: 0.87, blue: 0.96)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: size * 0.82, height: size * 0.52)
                    .shadow(color: Color.black.opacity(0.20), radius: size * 0.06, x: 0, y: size * 0.04)

                VolumetricCloudShape()
                    .stroke(
                        LinearGradient(
                            colors: [Color.white, Color.white.opacity(0.35), Color.clear],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: max(1.2, size * 0.025)
                    )
                    .frame(width: size * 0.82, height: size * 0.52)
            }
            .offset(x: -size * 0.06, y: size * 0.14 + cloudFloat)
        }
    }
}

// MARK: - 4. Partly Cloudy Night Graphic

private struct PartlyCloudyNightIllustration: View {
    let size: CGFloat
    let time: TimeInterval
    let animated: Bool

    var body: some View {
        let moonFloat = animated ? sin(time * 1.5) * (size * 0.015) : 0.0
        let cloudFloat = animated ? cos(time * 1.8) * (size * 0.015) : 0.0
        let starTwinkle = animated ? (sin(time * 3.0) + 1.0) * 0.5 : 0.8

        ZStack {
            // Sparkle star
            SparkleStarShape()
                .fill(Color.white)
                .frame(width: size * 0.15, height: size * 0.15)
                .position(x: size * 0.86, y: size * 0.18)
                .scaleEffect(0.65 + starTwinkle * 0.5)
                .opacity(0.40 + starTwinkle * 0.60)

            // Crescent Moon in background
            CrescentMoonShape()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 1.0, green: 0.98, blue: 0.90),
                            Color(red: 0.88, green: 0.92, blue: 0.98),
                            Color(red: 0.72, green: 0.82, blue: 0.96)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size * 0.48, height: size * 0.48)
                .shadow(color: Color(red: 0.65, green: 0.78, blue: 1.0).opacity(0.55), radius: size * 0.06)
                .offset(x: size * 0.16, y: -size * 0.16 + moonFloat)

            // Front nocturnal cloud
            ZStack {
                VolumetricCloudShape()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.45, green: 0.52, blue: 0.68),
                                Color(red: 0.28, green: 0.34, blue: 0.48),
                                Color(red: 0.18, green: 0.22, blue: 0.35)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: size * 0.82, height: size * 0.52)
                    .shadow(color: Color.black.opacity(0.35), radius: size * 0.07, x: 0, y: size * 0.04)

                VolumetricCloudShape()
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color(red: 0.88, green: 0.94, blue: 1.0).opacity(0.8),
                                Color.white.opacity(0.15),
                                Color.clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: max(1.2, size * 0.025)
                    )
                    .frame(width: size * 0.82, height: size * 0.52)
            }
            .offset(x: -size * 0.05, y: size * 0.14 + cloudFloat)
        }
    }
}

// MARK: - 5. Cloudy Graphic (Volumetric Layered Clouds)

private struct CloudyIllustration: View {
    let size: CGFloat
    let time: TimeInterval
    let animated: Bool

    var body: some View {
        let drift = animated ? sin(time * 1.5) * (size * 0.015) : 0.0

        ZStack {
            // Back cloud layer
            VolumetricCloudShape()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.70, green: 0.76, blue: 0.85),
                            Color(red: 0.52, green: 0.58, blue: 0.68)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: size * 0.76, height: size * 0.48)
                .offset(x: size * 0.08, y: -size * 0.10 - drift)

            // Front cloud layer
            ZStack {
                VolumetricCloudShape()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white,
                                Color(red: 0.90, green: 0.93, blue: 0.97),
                                Color(red: 0.74, green: 0.80, blue: 0.88)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: size * 0.86, height: size * 0.54)
                    .shadow(color: Color.black.opacity(0.24), radius: size * 0.06, x: 0, y: size * 0.04)

                VolumetricCloudShape()
                    .stroke(
                        LinearGradient(
                            colors: [Color.white, Color.white.opacity(0.35), Color.clear],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: max(1.2, size * 0.025)
                    )
                    .frame(width: size * 0.86, height: size * 0.54)
            }
            .offset(x: -size * 0.05, y: size * 0.08 + drift)
        }
    }
}

// MARK: - 6. Rainy Graphic (Volumetric Cloud & Cascading Animated Rain Drops)

private struct RainyIllustration: View {
    let isHeavy: Bool
    let size: CGFloat
    let time: TimeInterval
    let animated: Bool

    var body: some View {
        let cloudBob = animated ? sin(time * 1.6) * (size * 0.015) : 0.0
        let travel = size * 0.22

        // Continuous falling rain math (60-120fps continuous looping waterfall)
        let drop1Prog = animated ? (time * 1.6).truncatingRemainder(dividingBy: 1.0) : 0.3
        let drop2Prog = animated ? (time * 1.6 + 0.33).truncatingRemainder(dividingBy: 1.0) : 0.7
        let drop3Prog = animated ? (time * 1.6 + 0.66).truncatingRemainder(dividingBy: 1.0) : 0.5
        let drop4Prog = animated ? (time * 1.6 + 0.45).truncatingRemainder(dividingBy: 1.0) : 0.8

        ZStack {
            // Cascading angled raindrops
            ZStack {
                // Drop 1 (left)
                RainDropStreak(length: size * (isHeavy ? 0.24 : 0.18), width: size * 0.045)
                    .offset(x: -size * 0.22, y: size * 0.22 + CGFloat(drop1Prog) * travel)
                    .opacity(rainOpacity(progress: drop1Prog))

                // Drop 2 (center-left)
                RainDropStreak(length: size * (isHeavy ? 0.26 : 0.20), width: size * 0.048)
                    .offset(x: -size * 0.07, y: size * 0.20 + CGFloat(drop2Prog) * travel)
                    .opacity(rainOpacity(progress: drop2Prog))

                // Drop 3 (center-right)
                RainDropStreak(length: size * (isHeavy ? 0.24 : 0.18), width: size * 0.045)
                    .offset(x: size * 0.08, y: size * 0.22 + CGFloat(drop3Prog) * travel)
                    .opacity(rainOpacity(progress: drop3Prog))

                if isHeavy {
                    // Drop 4 (far right)
                    RainDropStreak(length: size * 0.24, width: size * 0.045)
                        .offset(x: size * 0.22, y: size * 0.21 + CGFloat(drop4Prog) * travel)
                        .opacity(rainOpacity(progress: drop4Prog))
                }
            }

            // Dark rain cloud body
            ZStack {
                VolumetricCloudShape()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.58, green: 0.65, blue: 0.76),
                                Color(red: 0.38, green: 0.45, blue: 0.58),
                                Color(red: 0.25, green: 0.30, blue: 0.42)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: size * 0.84, height: size * 0.52)
                    .shadow(color: Color(red: 0.1, green: 0.2, blue: 0.35).opacity(0.38), radius: size * 0.06, x: 0, y: size * 0.04)

                VolumetricCloudShape()
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.65),
                                Color.white.opacity(0.18),
                                Color.clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: max(1.2, size * 0.025)
                    )
                    .frame(width: size * 0.84, height: size * 0.52)
            }
            .offset(y: -size * 0.06 + cloudBob)
        }
    }

    private func rainOpacity(progress: Double) -> Double {
        if !animated { return 0.90 }
        if progress < 0.20 { return progress / 0.20 }
        if progress > 0.80 { return (1.0 - progress) / 0.20 }
        return 0.95
    }
}

// MARK: - 7. Thunderstorm Graphic (Moody Cloud & Glowing Electric Lightning)

private struct ThunderstormIllustration: View {
    let size: CGFloat
    let time: TimeInterval
    let animated: Bool

    var body: some View {
        let flashPulse = animated ? (sin(time * 3.5) + 1.0) * 0.5 : 0.8
        let rainProg = animated ? (time * 1.8).truncatingRemainder(dividingBy: 1.0) : 0.5

        ZStack {
            // Ambient electric bloom
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.6, green: 0.7, blue: 1.0).opacity(0.10 + flashPulse * 0.35),
                            Color(red: 0.8, green: 0.6, blue: 1.0).opacity(flashPulse * 0.18),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: size * 0.1,
                        endRadius: size * 0.45
                    )
                )
                .frame(width: size, height: size)

            // Lightning Bolt emerging under cloud
            ZStack {
                LightningBoltShape()
                    .fill(Color(red: 1.0, green: 0.85, blue: 0.2))
                    .frame(width: size * 0.32, height: size * 0.48)
                    .blur(radius: size * 0.06)
                    .opacity(0.40 + flashPulse * 0.60)

                LightningBoltShape()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white,
                                Color(red: 1.0, green: 0.95, blue: 0.5),
                                Color(red: 1.0, green: 0.78, blue: 0.1)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: size * 0.28, height: size * 0.44)
                    .shadow(color: Color(red: 1.0, green: 0.85, blue: 0.2), radius: size * 0.05)
            }
            .offset(x: size * 0.06, y: size * 0.22)
            .scaleEffect(0.95 + flashPulse * 0.10)

            // Falling rain streaks
            HStack(spacing: size * 0.28) {
                RainDropStreak(length: size * 0.22, width: size * 0.04)
                    .offset(y: size * 0.22 + CGFloat(rainProg) * size * 0.18)
                RainDropStreak(length: size * 0.22, width: size * 0.04)
                    .offset(y: size * 0.22 + CGFloat(rainProg) * size * 0.18)
            }
            .opacity(0.70)

            // Dark thundercloud
            ZStack {
                VolumetricCloudShape()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.45, green: 0.42, blue: 0.58),
                                Color(red: 0.28, green: 0.26, blue: 0.42),
                                Color(red: 0.16, green: 0.15, blue: 0.26)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: size * 0.86, height: size * 0.54)
                    .shadow(color: Color.black.opacity(0.45), radius: size * 0.08, x: 0, y: size * 0.04)

                VolumetricCloudShape()
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color(red: 0.85, green: 0.80, blue: 1.0).opacity(0.65),
                                Color.white.opacity(0.15),
                                Color.clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: max(1.2, size * 0.025)
                    )
                    .frame(width: size * 0.86, height: size * 0.54)
            }
            .offset(y: -size * 0.08)
        }
    }
}

// MARK: - 8. Snowy Graphic (Frosted Cloud & Drifting Crystalline Snowflakes)

private struct SnowyIllustration: View {
    let size: CGFloat
    let time: TimeInterval
    let animated: Bool

    var body: some View {
        let rot = animated ? (time * 45.0).truncatingRemainder(dividingBy: 360.0) : 0.0
        let sway = animated ? sin(time * 2.0) * (size * 0.03) : 0.0

        ZStack {
            // Drifting snowflakes
            ZStack {
                SnowflakeShape()
                    .fill(Color.white)
                    .frame(width: size * 0.16, height: size * 0.16)
                    .shadow(color: Color(red: 0.7, green: 0.85, blue: 1.0).opacity(0.8), radius: size * 0.03)
                    .rotationEffect(.degrees(rot))
                    .offset(x: -size * 0.22 + sway, y: size * 0.24)

                SnowflakeShape()
                    .fill(Color(red: 0.88, green: 0.95, blue: 1.0))
                    .frame(width: size * 0.18, height: size * 0.18)
                    .shadow(color: Color(red: 0.7, green: 0.85, blue: 1.0).opacity(0.8), radius: size * 0.03)
                    .rotationEffect(.degrees(-rot * 0.8))
                    .offset(x: 0 - sway * 0.8, y: size * 0.28)

                SnowflakeShape()
                    .fill(Color.white)
                    .frame(width: size * 0.14, height: size * 0.14)
                    .rotationEffect(.degrees(rot * 1.2))
                    .offset(x: size * 0.22 + sway, y: size * 0.23)
            }

            // Frosted winter cloud
            ZStack {
                VolumetricCloudShape()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white,
                                Color(red: 0.92, green: 0.96, blue: 1.0),
                                Color(red: 0.75, green: 0.85, blue: 0.96)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: size * 0.84, height: size * 0.52)
                    .shadow(color: Color(red: 0.4, green: 0.6, blue: 0.8).opacity(0.25), radius: size * 0.06, x: 0, y: size * 0.04)

                VolumetricCloudShape()
                    .stroke(
                        LinearGradient(
                            colors: [Color.white, Color(red: 0.8, green: 0.9, blue: 1.0).opacity(0.55), Color.clear],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: max(1.2, size * 0.025)
                    )
                    .frame(width: size * 0.84, height: size * 0.52)
            }
            .offset(y: -size * 0.08)
        }
    }
}

// MARK: - 9. Windy Graphic (Breezy Cloud & Wind Gust Ribbons)

private struct WindyIllustration: View {
    let size: CGFloat
    let time: TimeInterval
    let animated: Bool

    var body: some View {
        let gust = animated ? sin(time * 2.2) * (size * 0.05) : 0.0

        ZStack {
            VolumetricCloudShape()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white,
                            Color(red: 0.90, green: 0.94, blue: 0.98),
                            Color(red: 0.78, green: 0.85, blue: 0.94)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: size * 0.76, height: size * 0.48)
                .offset(x: -size * 0.08, y: -size * 0.08)

            VStack(spacing: size * 0.08) {
                WindStreamlineShape()
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color(red: 0.55, green: 0.82, blue: 1.0).opacity(0.20),
                                Color(red: 0.75, green: 0.92, blue: 1.0),
                                Color.white
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: max(1.5, size * 0.035), lineCap: .round)
                    )
                    .frame(width: size * 0.65, height: size * 0.08)
                    .offset(x: gust)

                WindStreamlineShape()
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color(red: 0.55, green: 0.82, blue: 1.0).opacity(0.20),
                                Color(red: 0.75, green: 0.92, blue: 1.0),
                                Color.white
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: max(1.5, size * 0.035), lineCap: .round)
                    )
                    .frame(width: size * 0.52, height: size * 0.08)
                    .offset(x: -gust * 0.8 + size * 0.05)
            }
            .offset(y: size * 0.22)
        }
    }
}

// MARK: - 10. Foggy Graphic (Ethereal Mist Bars)

private struct FoggyIllustration: View {
    let size: CGFloat
    let time: TimeInterval
    let animated: Bool

    var body: some View {
        let drift = animated ? sin(time * 1.4) * (size * 0.04) : 0.0

        VStack(spacing: size * 0.08) {
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.20),
                            Color.white.opacity(0.85),
                            Color.white.opacity(0.20)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: size * 0.72, height: max(3, size * 0.07))
                .offset(x: drift)

            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.30),
                            Color.white.opacity(0.95),
                            Color.white.opacity(0.30)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: size * 0.86, height: max(3.5, size * 0.08))
                .offset(x: -drift * 1.2)

            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.15),
                            Color.white.opacity(0.75),
                            Color.white.opacity(0.15)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: size * 0.65, height: max(3, size * 0.07))
                .offset(x: drift * 0.8)
        }
    }
}

// MARK: - Vector Shapes & Primitives

// 1. Sun Corona Rays
private struct SunRaysView: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            ForEach(0..<8) { i in
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 1.0, green: 0.88, blue: 0.35),
                                Color(red: 1.0, green: 0.60, blue: 0.12).opacity(0.65)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: max(2, size * 0.06), height: size * 0.20)
                    .offset(y: -size * 0.40)
                    .rotationEffect(.degrees(Double(i) * 45))
            }
        }
    }
}

// 2. Crescent Moon Shape
private struct CrescentMoonShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height

        path.move(to: CGPoint(x: w * 0.72, y: h * 0.08))
        path.addCurve(
            to: CGPoint(x: w * 0.72, y: h * 0.92),
            control1: CGPoint(x: -w * 0.08, y: h * 0.20),
            control2: CGPoint(x: -w * 0.08, y: h * 0.80)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.72, y: h * 0.08),
            control1: CGPoint(x: w * 0.25, y: h * 0.75),
            control2: CGPoint(x: w * 0.25, y: h * 0.25)
        )
        path.closeSubpath()
        return path
    }
}

// 3. Sparkle Star Shape
private struct SparkleStarShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let midX = rect.midX
        let midY = rect.midY
        let w = rect.width
        let h = rect.height

        path.move(to: CGPoint(x: midX, y: 0))
        path.addQuadCurve(to: CGPoint(x: w, y: midY), control: CGPoint(x: midX + w * 0.12, y: midY - h * 0.12))
        path.addQuadCurve(to: CGPoint(x: midX, y: h), control: CGPoint(x: midX + w * 0.12, y: midY + h * 0.12))
        path.addQuadCurve(to: CGPoint(x: 0, y: midY), control: CGPoint(x: midX - w * 0.12, y: midY + h * 0.12))
        path.addQuadCurve(to: CGPoint(x: midX, y: 0), control: CGPoint(x: midX - w * 0.12, y: midY - h * 0.12))
        path.closeSubpath()
        return path
    }
}

// 4. Volumetric Cloud Compound Shape
private struct VolumetricCloudShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height

        let baseRect = CGRect(x: w * 0.05, y: h * 0.45, width: w * 0.90, height: h * 0.45)
        path.addRoundedRect(in: baseRect, cornerSize: CGSize(width: h * 0.22, height: h * 0.22))

        let centerPuff = CGRect(x: w * 0.32, y: h * 0.12, width: w * 0.44, height: h * 0.68)
        path.addEllipse(in: centerPuff)

        let leftPuff = CGRect(x: w * 0.12, y: h * 0.26, width: w * 0.36, height: h * 0.54)
        path.addEllipse(in: leftPuff)

        let rightPuff = CGRect(x: w * 0.58, y: h * 0.32, width: w * 0.32, height: h * 0.48)
        path.addEllipse(in: rightPuff)

        return path
    }
}

// 5. Rain Drop Streak
private struct RainDropStreak: View {
    let length: CGFloat
    let width: CGFloat

    var body: some View {
        Capsule()
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.50, green: 0.85, blue: 1.0),
                        Color(red: 0.15, green: 0.55, blue: 0.95)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: width, height: length)
            .rotationEffect(.degrees(16))
    }
}

// 6. Lightning Bolt Shape
private struct LightningBoltShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height

        path.move(to: CGPoint(x: w * 0.62, y: 0))
        path.addLine(to: CGPoint(x: w * 0.22, y: h * 0.50))
        path.addLine(to: CGPoint(x: w * 0.48, y: h * 0.50))
        path.addLine(to: CGPoint(x: w * 0.32, y: h))
        path.addLine(to: CGPoint(x: w * 0.82, y: h * 0.42))
        path.addLine(to: CGPoint(x: w * 0.54, y: h * 0.42))
        path.closeSubpath()
        return path
    }
}

// 7. Snowflake Shape
private struct SnowflakeShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let midX = rect.midX
        let midY = rect.midY
        let radius = min(rect.width, rect.height) / 2

        for i in 0..<6 {
            let angle = Double(i) * (.pi / 3)
            let endX = midX + CGFloat(cos(angle)) * radius
            let endY = midY + CGFloat(sin(angle)) * radius

            path.move(to: CGPoint(x: midX, y: midY))
            path.addLine(to: CGPoint(x: endX, y: endY))

            let b1X = midX + CGFloat(cos(angle)) * (radius * 0.65)
            let b1Y = midY + CGFloat(sin(angle)) * (radius * 0.65)
            let branchAngle1 = angle + .pi / 4
            let branchAngle2 = angle - .pi / 4
            let bLen = radius * 0.28

            path.move(to: CGPoint(x: b1X, y: b1Y))
            path.addLine(to: CGPoint(x: b1X + CGFloat(cos(branchAngle1)) * bLen, y: b1Y + CGFloat(sin(branchAngle1)) * bLen))

            path.move(to: CGPoint(x: b1X, y: b1Y))
            path.addLine(to: CGPoint(x: b1X + CGFloat(cos(branchAngle2)) * bLen, y: b1Y + CGFloat(sin(branchAngle2)) * bLen))
        }
        return path
    }
}

// 8. Wind Streamline Ribbon
private struct WindStreamlineShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height

        path.move(to: CGPoint(x: 0, y: h * 0.5))
        path.addCurve(
            to: CGPoint(x: w * 0.8, y: h * 0.3),
            control1: CGPoint(x: w * 0.3, y: h * 0.9),
            control2: CGPoint(x: w * 0.6, y: -h * 0.2)
        )
        path.addQuadCurve(
            to: CGPoint(x: w, y: h * 0.8),
            control: CGPoint(x: w * 0.95, y: h * 0.5)
        )
        return path
    }
}
