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

        // Check night first
        if sym.contains("moon") || cond.contains("night") {
            return .night
        }

        // Thunderstorm
        if cond.contains("thunder") || cond.contains("storm") || cond.contains("lightning") || sym.contains("bolt") {
            return .thunderstorm
        }

        // Snow / Sleet / Hail
        if cond.contains("snow") || cond.contains("blizzard") || cond.contains("flurr") || cond.contains("sleet") || cond.contains("hail") || sym.contains("snow") {
            return .snowy
        }

        // Rain / Drizzle / Showers
        if cond.contains("rain") || cond.contains("drizzle") || cond.contains("shower") || sym.contains("rain") || sym.contains("drizzle") {
            return .rainy
        }

        // Cloudy / Overcast / Fog / Mist / Haze
        if cond.contains("overcast") || cond.contains("fog") || cond.contains("mist") || cond.contains("haze") || cond.contains("smoke") || cond == "cloudy" {
            return .cloudy
        }

        if cond.contains("partly cloudy") || cond.contains("cloud") || sym.contains("cloud") {
            return .partlyCloudy
        }

        // Sunny / Clear
        if cond.contains("sun") || cond.contains("clear") || sym.contains("sun") {
            return .sunny
        }

        return .partlyCloudy
    }

    public var gradientColors: [Color] {
        switch self {
        case .sunny:
            return [
                Color(red: 0.15, green: 0.50, blue: 0.92),
                Color(red: 0.25, green: 0.62, blue: 0.95),
                Color(red: 0.88, green: 0.68, blue: 0.32).opacity(0.65),
                Color(red: 0.08, green: 0.32, blue: 0.70)
            ]
        case .partlyCloudy:
            return [
                Color(red: 0.18, green: 0.42, blue: 0.80),
                Color(red: 0.24, green: 0.48, blue: 0.78),
                Color(red: 0.12, green: 0.28, blue: 0.60),
                Color(red: 0.06, green: 0.18, blue: 0.46)
            ]
        case .cloudy:
            return [
                Color(red: 0.16, green: 0.26, blue: 0.42),
                Color(red: 0.24, green: 0.35, blue: 0.50),
                Color(red: 0.18, green: 0.28, blue: 0.44),
                Color(red: 0.09, green: 0.15, blue: 0.28)
            ]
        case .rainy:
            return [
                Color(red: 0.08, green: 0.18, blue: 0.35),
                Color(red: 0.12, green: 0.25, blue: 0.44),
                Color(red: 0.15, green: 0.28, blue: 0.46),
                Color(red: 0.05, green: 0.12, blue: 0.26)
            ]
        case .thunderstorm:
            return [
                Color(red: 0.06, green: 0.08, blue: 0.20),
                Color(red: 0.10, green: 0.12, blue: 0.26),
                Color(red: 0.14, green: 0.16, blue: 0.32),
                Color(red: 0.04, green: 0.05, blue: 0.14)
            ]
        case .snowy:
            return [
                Color(red: 0.20, green: 0.38, blue: 0.62),
                Color(red: 0.30, green: 0.50, blue: 0.72),
                Color(red: 0.45, green: 0.62, blue: 0.82),
                Color(red: 0.12, green: 0.24, blue: 0.48)
            ]
        case .night:
            return [
                Color(red: 0.04, green: 0.06, blue: 0.18),
                Color(red: 0.08, green: 0.10, blue: 0.28),
                Color(red: 0.06, green: 0.08, blue: 0.22),
                Color(red: 0.02, green: 0.03, blue: 0.10)
            ]
        case .defaultTheme:
            return [
                Color(red: 0.18, green: 0.42, blue: 0.82),
                Color(red: 0.05, green: 0.19, blue: 0.50)
            ]
        }
    }
}

// MARK: - WeatherBackgroundView

public struct WeatherBackgroundView: View {
    public let type: WeatherVisualType

    public init(type: WeatherVisualType) {
        self.type = type
    }

    public init(condition: String?, symbolName: String? = nil) {
        self.type = WeatherVisualType.from(condition: condition, symbolName: symbolName)
    }

    public var body: some View {
        ZStack {
            // Base Gradient with smooth crossfade
            LinearGradient(
                colors: type.gradientColors,
                startPoint: .top,
                endPoint: .bottom
            )
            .animation(.easeInOut(duration: 1.2), value: type)

            // Dynamic Atmospheric Animation Layers
            switch type {
            case .sunny:
                SunnyAtmosphereView()
            case .partlyCloudy:
                CloudyAtmosphereView(cloudDensity: .light)
            case .cloudy:
                CloudyAtmosphereView(cloudDensity: .dense)
            case .rainy:
                RainyAtmosphereView(heavy: false)
            case .thunderstorm:
                ThunderstormAtmosphereView()
            case .snowy:
                SnowyAtmosphereView()
            case .night:
                NightAtmosphereView()
            case .defaultTheme:
                CloudyAtmosphereView(cloudDensity: .light)
            }

            // Contrast preservation gradient vignette (ensures text & cards always remain readable)
            LinearGradient(
                colors: [
                    Color.black.opacity(0.18),
                    Color.clear,
                    Color.black.opacity(0.28)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)
        }
        .ignoresSafeArea()
    }
}

// MARK: - Sunny Atmosphere (Sun glow, soft lens flare, floating light motes)

private struct SunnyAtmosphereView: View {
    @State private var sunPulse = false
    @State private var haloRotate = 0.0

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let elapsed = timeline.date.timeIntervalSinceReferenceDate

            Canvas { context, size in
                // Warm ambient sun flare
                let sunCenter = CGPoint(x: size.width * 0.82, y: size.height * 0.14)
                let baseRadius = size.width * 0.45
                let pulse = 1.0 + 0.06 * sin(elapsed * 1.2)

                let gradient = Gradient(colors: [
                    Color(red: 1.0, green: 0.92, blue: 0.65).opacity(0.45),
                    Color(red: 1.0, green: 0.75, blue: 0.35).opacity(0.22),
                    Color(red: 1.0, green: 0.60, blue: 0.20).opacity(0.08),
                    Color.clear
                ])

                context.fill(
                    Path(ellipseIn: CGRect(
                        x: sunCenter.x - (baseRadius * pulse),
                        y: sunCenter.y - (baseRadius * pulse),
                        width: baseRadius * 2 * pulse,
                        height: baseRadius * 2 * pulse
                    )),
                    with: .radialGradient(
                        gradient,
                        center: sunCenter,
                        startRadius: 10,
                        endRadius: baseRadius * pulse
                    )
                )

                // Sun disc core
                let coreGradient = Gradient(colors: [
                    Color.white.opacity(0.85),
                    Color(red: 1.0, green: 0.95, blue: 0.70).opacity(0.60),
                    Color.clear
                ])
                let coreRadius: CGFloat = 48.0
                context.fill(
                    Path(ellipseIn: CGRect(
                        x: sunCenter.x - coreRadius,
                        y: sunCenter.y - coreRadius,
                        width: coreRadius * 2,
                        height: coreRadius * 2
                    )),
                    with: .radialGradient(coreGradient, center: sunCenter, startRadius: 0, endRadius: coreRadius)
                )

                // Gentle floating warm sun dust particles
                let dustCount = 18
                for i in 0..<dustCount {
                    let seed = Double(i) * 31.7
                    let speed = 0.15 + (Double(i % 5) * 0.04)
                    let yProgress = (elapsed * speed + seed).truncatingRemainder(dividingBy: 1.0)
                    let xPos = (sin(elapsed * 0.4 + seed) * 0.35 + 0.5) * size.width
                    let yPos = CGFloat(yProgress) * size.height
                    let opacity = sin(yProgress * .pi) * 0.35
                    let particleRadius = CGFloat(1.5 + Double(i % 4))

                    context.opacity = opacity
                    context.fill(
                        Path(ellipseIn: CGRect(
                            x: xPos - particleRadius,
                            y: yPos - particleRadius,
                            width: particleRadius * 2,
                            height: particleRadius * 2
                        )),
                        with: .color(Color(red: 1.0, green: 0.96, blue: 0.75))
                    )
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Cloudy Atmosphere (Layered drifting organic clouds)

private struct CloudyAtmosphereView: View {
    enum Density { case light, dense }
    let cloudDensity: Density

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let elapsed = timeline.date.timeIntervalSinceReferenceDate

            Canvas { context, size in
                let cloudCount = cloudDensity == .dense ? 7 : 4

                for i in 0..<cloudCount {
                    let speed = 8.0 + Double(i) * 5.0 // pt/sec
                    let yRatio = 0.08 + Double(i) * 0.12
                    let width = size.width * (0.8 + CGFloat(i % 3) * 0.3)
                    let height: CGFloat = 130 + CGFloat(i * 15)

                    let totalDistance = size.width + width
                    let xOffset = (CGFloat(elapsed * speed) + CGFloat(i * 180)).truncatingRemainder(dividingBy: totalDistance) - width * 0.5

                    let opacity = cloudDensity == .dense ? (0.16 + Double(i % 3) * 0.06) : (0.10 + Double(i % 2) * 0.05)

                    context.opacity = opacity

                    let cloudRect = CGRect(
                        x: xOffset,
                        y: size.height * CGFloat(yRatio),
                        width: width,
                        height: height
                    )

                    let cloudGradient = Gradient(colors: [
                        Color.white.opacity(0.85),
                        Color.white.opacity(0.40),
                        Color.clear
                    ])

                    context.fill(
                        Path(ellipseIn: cloudRect),
                        with: .radialGradient(
                            cloudGradient,
                            center: CGPoint(x: cloudRect.midX, y: cloudRect.midY),
                            startRadius: 0,
                            endRadius: width * 0.5
                        )
                    )
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Rainy Atmosphere (Realistic angled falling rain streaks & puddle splashes)

private struct RainyAtmosphereView: View {
    let heavy: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            let elapsed = timeline.date.timeIntervalSinceReferenceDate

            Canvas { context, size in
                // Distant cloud gloom
                let cloudRect = CGRect(x: -size.width * 0.2, y: -50, width: size.width * 1.4, height: size.height * 0.45)
                context.opacity = 0.28
                context.fill(
                    Path(ellipseIn: cloudRect),
                    with: .radialGradient(
                        Gradient(colors: [Color.black.opacity(0.6), Color.clear]),
                        center: CGPoint(x: cloudRect.midX, y: cloudRect.midY),
                        startRadius: 20,
                        endRadius: cloudRect.width * 0.5
                    )
                )

                // Angled rain streaks
                let dropCount = heavy ? 110 : 70
                let angle: CGFloat = 0.12 // slight tilt

                for i in 0..<dropCount {
                    let seed = Double(i) * 53.13
                    let speed = heavy ? (550.0 + Double(i % 10) * 45.0) : (420.0 + Double(i % 8) * 35.0)
                    let length = CGFloat(16 + (i % 6) * 4)

                    let xBase = CGFloat((seed.truncatingRemainder(dividingBy: 1.0))) * size.width
                    let totalHeight = size.height + length + 40
                    let yPos = (CGFloat(elapsed * speed) + CGFloat(seed * 200)).truncatingRemainder(dividingBy: totalHeight) - length
                    let xPos = xBase + (yPos * angle)

                    let opacity = 0.22 + Double(i % 5) * 0.08

                    var path = Path()
                    path.move(to: CGPoint(x: xPos, y: yPos))
                    path.addLine(to: CGPoint(x: xPos + (length * angle), y: yPos + length))

                    context.opacity = opacity
                    context.stroke(
                        path,
                        with: .color(Color(red: 0.82, green: 0.90, blue: 1.0)),
                        lineWidth: CGFloat(1.2 + Double(i % 3) * 0.4)
                    )
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Thunderstorm Atmosphere (Rain + Ambient lightning flash)

private struct ThunderstormAtmosphereView: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            let elapsed = timeline.date.timeIntervalSinceReferenceDate

            // Lightning cycle: every ~6.5 seconds with double flicker
            let cycle = elapsed.truncatingRemainder(dividingBy: 6.5)
            let isFlashing = (cycle > 4.8 && cycle < 4.95) || (cycle > 5.05 && cycle < 5.22)
            let flashOpacity = isFlashing ? (cycle > 5.05 ? 0.45 : 0.65) : 0.0

            ZStack {
                // Rain layer
                RainyAtmosphereView(heavy: true)

                // Lightning ambient illumination
                Color(red: 0.85, green: 0.90, blue: 1.0)
                    .opacity(flashOpacity)
                    .animation(.easeOut(duration: 0.12), value: flashOpacity)
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Snowy Atmosphere (Gentle drifting snowflakes with harmonic sway)

private struct SnowyAtmosphereView: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            let elapsed = timeline.date.timeIntervalSinceReferenceDate

            Canvas { context, size in
                let flakeCount = 55

                for i in 0..<flakeCount {
                    let seed = Double(i) * 41.17
                    let speed = 40.0 + Double(i % 6) * 16.0 // px/sec
                    let radius = CGFloat(1.8 + Double(i % 5) * 1.0)

                    let totalHeight = size.height + 40
                    let yPos = (CGFloat(elapsed * speed) + CGFloat(seed * 180)).truncatingRemainder(dividingBy: totalHeight) - 20

                    // Sinusoidal horizontal sway
                    let swayAmplitude = CGFloat(14 + (i % 4) * 8)
                    let swayFrequency = 1.2 + Double(i % 3) * 0.4
                    let xBase = CGFloat((seed.truncatingRemainder(dividingBy: 1.0))) * size.width
                    let xPos = xBase + (sin(elapsed * swayFrequency + seed) * swayAmplitude)

                    let opacity = 0.35 + Double(i % 4) * 0.15

                    context.opacity = opacity
                    context.fill(
                        Path(ellipseIn: CGRect(
                            x: xPos - radius,
                            y: yPos - radius,
                            width: radius * 2,
                            height: radius * 2
                        )),
                        with: .color(.white)
                    )
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Night Atmosphere (Twinkling stars & subtle lunar glow)

private struct NightAtmosphereView: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let elapsed = timeline.date.timeIntervalSinceReferenceDate

            Canvas { context, size in
                // Subtle moon glow
                let moonCenter = CGPoint(x: size.width * 0.82, y: size.height * 0.15)
                let moonRadius: CGFloat = 32
                let glowRadius: CGFloat = 140

                context.fill(
                    Path(ellipseIn: CGRect(
                        x: moonCenter.x - glowRadius,
                        y: moonCenter.y - glowRadius,
                        width: glowRadius * 2,
                        height: glowRadius * 2
                    )),
                    with: .radialGradient(
                        Gradient(colors: [
                            Color(red: 0.85, green: 0.90, blue: 1.0).opacity(0.18),
                            Color.clear
                        ]),
                        center: moonCenter,
                        startRadius: 10,
                        endRadius: glowRadius
                    )
                )

                context.fill(
                    Path(ellipseIn: CGRect(
                        x: moonCenter.x - moonRadius,
                        y: moonCenter.y - moonRadius,
                        width: moonRadius * 2,
                        height: moonRadius * 2
                    )),
                    with: .radialGradient(
                        Gradient(colors: [
                            Color(red: 0.95, green: 0.98, blue: 1.0).opacity(0.85),
                            Color(red: 0.80, green: 0.88, blue: 1.0).opacity(0.50)
                        ]),
                        center: moonCenter,
                        startRadius: 0,
                        endRadius: moonRadius
                    )
                )

                // Twinkling stars
                let starCount = 35
                for i in 0..<starCount {
                    let seed = Double(i) * 29.31
                    let xPos = (seed.truncatingRemainder(dividingBy: 1.0)) * size.width
                    let yPos = ((seed * 1.7).truncatingRemainder(dividingBy: 0.7)) * size.height

                    let pulseSpeed = 1.5 + Double(i % 4) * 0.7
                    let opacity = 0.25 + 0.55 * (0.5 + 0.5 * sin(elapsed * pulseSpeed + seed))
                    let r = CGFloat(1.0 + Double(i % 3) * 0.6)

                    context.opacity = opacity
                    context.fill(
                        Path(ellipseIn: CGRect(x: xPos - r, y: yPos - r, width: r * 2, height: r * 2)),
                        with: .color(.white)
                    )
                }
            }
        }
        .allowsHitTesting(false)
    }
}
