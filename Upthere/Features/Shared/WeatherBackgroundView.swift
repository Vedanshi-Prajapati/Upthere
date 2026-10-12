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
    public let type: WeatherVisualType

    public init(type: WeatherVisualType) {
        self.type = type
    }

    public init(condition: String?, symbolName: String? = nil) {
        self.type = WeatherVisualType.from(condition: condition, symbolName: symbolName)
    }

    public var body: some View {
        ZStack {
            // Layer 1: Living, organic atmospheric mesh / auroral blooms
            AtmosphericMeshSky(type: type)

            // Layer 2: Condition-specific organic particle and light dynamics
            switch type {
            case .sunny:
                SunnyLightAtmosphere()
            case .partlyCloudy:
                CloudDriftAtmosphere(density: .light)
            case .cloudy:
                CloudDriftAtmosphere(density: .dense)
            case .rainy:
                RainfallAtmosphere(heavy: false)
            case .thunderstorm:
                ThunderstormAtmosphere()
            case .snowy:
                SnowfallAtmosphere()
            case .night:
                NightStarlightAtmosphere()
            case .defaultTheme:
                CloudDriftAtmosphere(density: .light)
            }

            // Layer 3: Ultra-delicate contrast vignette for razor-sharp typography
            LinearGradient(
                colors: [
                    Color.black.opacity(0.12),
                    Color.clear,
                    Color.black.opacity(0.24)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)
        }
        .ignoresSafeArea()
    }
}

// MARK: - Living Organic Mesh Sky (Smooth Multi-blob drifting aurora gradient)

private struct AtmosphericMeshSky: View {
    let type: WeatherVisualType

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate

            // Organic drifting offsets for ambient light blobs
            let blob1X = CGFloat(sin(t * 0.18) * 0.15)
            let blob1Y = CGFloat(cos(t * 0.14) * 0.12)

            let blob2X = CGFloat(cos(t * 0.16) * 0.16)
            let blob2Y = CGFloat(sin(t * 0.20) * 0.14)

            let blob3X = CGFloat(sin(t * 0.12) * 0.18)
            let blob3Y = CGFloat(cos(t * 0.15) * 0.10)

            GeometryReader { proxy in
                let w = proxy.size.width
                let h = proxy.size.height

                ZStack {
                    // Deep base backdrop
                    baseColor(for: type)

                    // Secondary ambient light blob top-right
                    RadialGradient(
                        colors: [ambientLightColor(for: type).opacity(0.65), Color.clear],
                        center: UnitPoint(x: 0.75 + blob1X, y: 0.20 + blob1Y),
                        startRadius: 20,
                        endRadius: max(w, h) * 0.65
                    )
                    .blur(radius: 50)

                    // Third horizon glow blob
                    RadialGradient(
                        colors: [horizonLightColor(for: type).opacity(0.50), Color.clear],
                        center: UnitPoint(x: 0.30 + blob2X, y: 0.65 + blob2Y),
                        startRadius: 30,
                        endRadius: max(w, h) * 0.60
                    )
                    .blur(radius: 65)

                    // Counter-balance subtle atmospheric aura top-left
                    RadialGradient(
                        colors: [accentGlowColor(for: type).opacity(0.40), Color.clear],
                        center: UnitPoint(x: 0.15 + blob3X, y: 0.10 + blob3Y),
                        startRadius: 10,
                        endRadius: max(w, h) * 0.50
                    )
                    .blur(radius: 40)
                }
            }
        }
        .animation(.easeInOut(duration: 1.2), value: type)
        .allowsHitTesting(false)
    }

    private func baseColor(for type: WeatherVisualType) -> Color {
        switch type {
        case .sunny:
            return Color(red: 0.10, green: 0.38, blue: 0.82)
        case .partlyCloudy:
            return Color(red: 0.12, green: 0.30, blue: 0.64)
        case .cloudy:
            return Color(red: 0.13, green: 0.20, blue: 0.34)
        case .rainy:
            return Color(red: 0.08, green: 0.15, blue: 0.28)
        case .thunderstorm:
            return Color(red: 0.05, green: 0.07, blue: 0.18)
        case .snowy:
            return Color(red: 0.16, green: 0.30, blue: 0.52)
        case .night:
            return Color(red: 0.04, green: 0.06, blue: 0.15)
        case .defaultTheme:
            return Color(red: 0.11, green: 0.28, blue: 0.62)
        }
    }

    private func ambientLightColor(for type: WeatherVisualType) -> Color {
        switch type {
        case .sunny:
            return Color(red: 0.98, green: 0.72, blue: 0.32) // Warm solar amber
        case .partlyCloudy:
            return Color(red: 0.38, green: 0.60, blue: 0.92) // Crisp azure
        case .cloudy:
            return Color(red: 0.32, green: 0.44, blue: 0.60) // Silver slate
        case .rainy:
            return Color(red: 0.18, green: 0.32, blue: 0.50) // Deep ocean blue
        case .thunderstorm:
            return Color(red: 0.22, green: 0.20, blue: 0.45) // Electric dark violet
        case .snowy:
            return Color(red: 0.45, green: 0.65, blue: 0.88) // Frosted ice blue
        case .night:
            return Color(red: 0.12, green: 0.16, blue: 0.38) // Midnight indigo
        case .defaultTheme:
            return Color(red: 0.30, green: 0.55, blue: 0.88)
        }
    }

    private func horizonLightColor(for type: WeatherVisualType) -> Color {
        switch type {
        case .sunny:
            return Color(red: 0.22, green: 0.62, blue: 0.96)
        case .partlyCloudy:
            return Color(red: 0.20, green: 0.45, blue: 0.82)
        case .cloudy:
            return Color(red: 0.20, green: 0.30, blue: 0.45)
        case .rainy:
            return Color(red: 0.12, green: 0.22, blue: 0.38)
        case .thunderstorm:
            return Color(red: 0.10, green: 0.12, blue: 0.26)
        case .snowy:
            return Color(red: 0.30, green: 0.48, blue: 0.72)
        case .night:
            return Color(red: 0.08, green: 0.10, blue: 0.25)
        case .defaultTheme:
            return Color(red: 0.18, green: 0.42, blue: 0.80)
        }
    }

    private func accentGlowColor(for type: WeatherVisualType) -> Color {
        switch type {
        case .sunny:
            return Color(red: 0.99, green: 0.85, blue: 0.50)
        case .partlyCloudy:
            return Color(red: 0.42, green: 0.68, blue: 0.98)
        case .cloudy:
            return Color(red: 0.28, green: 0.38, blue: 0.52)
        case .rainy:
            return Color(red: 0.15, green: 0.26, blue: 0.42)
        case .thunderstorm:
            return Color(red: 0.18, green: 0.18, blue: 0.36)
        case .snowy:
            return Color(red: 0.60, green: 0.75, blue: 0.95)
        case .night:
            return Color(red: 0.10, green: 0.14, blue: 0.30)
        case .defaultTheme:
            return Color(red: 0.25, green: 0.50, blue: 0.85)
        }
    }
}

// MARK: - Sunny Light Atmosphere (Atmospheric Lens Flare & Solar Shimmer)

private struct SunnyLightAtmosphere: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate

            Canvas { context, size in
                let sunCenter = CGPoint(x: size.width * 0.84, y: size.height * 0.12)
                let pulse = 1.0 + 0.04 * sin(t * 0.8)

                // Soft corona aura
                let coronaRadius = size.width * 0.65 * pulse
                let coronaGradient = Gradient(colors: [
                    Color(red: 1.0, green: 0.90, blue: 0.62).opacity(0.35),
                    Color(red: 1.0, green: 0.72, blue: 0.30).opacity(0.18),
                    Color(red: 1.0, green: 0.55, blue: 0.15).opacity(0.05),
                    Color.clear
                ])

                context.fill(
                    Path(ellipseIn: CGRect(
                        x: sunCenter.x - coronaRadius,
                        y: sunCenter.y - coronaRadius,
                        width: coronaRadius * 2,
                        height: coronaRadius * 2
                    )),
                    with: .radialGradient(coronaGradient, center: sunCenter, startRadius: 10, endRadius: coronaRadius)
                )

                // Subtle solar rays (broad soft fan)
                for angleIndex in 0..<6 {
                    let rayAngle = Double(angleIndex) * (.pi / 3.0) + (t * 0.02)
                    let rayLength = size.width * 0.8

                    var path = Path()
                    path.move(to: sunCenter)
                    let p1 = CGPoint(
                        x: sunCenter.x + cos(rayAngle - 0.12) * rayLength,
                        y: sunCenter.y + sin(rayAngle - 0.12) * rayLength
                    )
                    let p2 = CGPoint(
                        x: sunCenter.x + cos(rayAngle + 0.12) * rayLength,
                        y: sunCenter.y + sin(rayAngle + 0.12) * rayLength
                    )
                    path.addLine(to: p1)
                    path.addLine(to: p2)
                    path.closeSubpath()

                    let rayGradient = Gradient(colors: [
                        Color(red: 1.0, green: 0.92, blue: 0.68).opacity(0.08),
                        Color.clear
                    ])
                    context.fill(
                        path,
                        with: .radialGradient(rayGradient, center: sunCenter, startRadius: 10, endRadius: rayLength)
                    )
                }

                // Shimmering micro motes
                for i in 0..<16 {
                    let seed = Double(i) * 37.1
                    let speed = 0.10 + Double(i % 4) * 0.03
                    let yProgress = (t * speed + seed).truncatingRemainder(dividingBy: 1.0)
                    let xPos = (sin(t * 0.25 + seed) * 0.35 + 0.5) * size.width
                    let yPos = CGFloat(yProgress) * size.height
                    let opacity = sin(yProgress * .pi) * 0.28
                    let r = CGFloat(1.5 + Double(i % 3) * 0.8)

                    context.opacity = opacity
                    context.fill(
                        Path(ellipseIn: CGRect(x: xPos - r, y: yPos - r, width: r * 2, height: r * 2)),
                        with: .color(Color(red: 1.0, green: 0.95, blue: 0.75))
                    )
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Cloud Drift Atmosphere (Atmospheric Mist & Soft Billows)

private struct CloudDriftAtmosphere: View {
    enum Density { case light, dense }
    let density: Density

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate

            Canvas { context, size in
                let count = density == .dense ? 6 : 4

                for i in 0..<count {
                    let speed = 6.0 + Double(i) * 3.5 // pt/sec
                    let width = size.width * (1.1 + CGFloat(i % 3) * 0.3)
                    let height: CGFloat = 180 + CGFloat(i * 25)
                    let totalDistance = size.width + width

                    let xOffset = (CGFloat(t * speed) + CGFloat(i * 220)).truncatingRemainder(dividingBy: totalDistance) - width * 0.5
                    let yRatio = 0.05 + Double(i) * 0.16
                    let yPos = size.height * CGFloat(yRatio)

                    let opacity = density == .dense ? (0.10 + Double(i % 3) * 0.04) : (0.06 + Double(i % 2) * 0.03)

                    context.opacity = opacity

                    let rect = CGRect(x: xOffset, y: yPos, width: width, height: height)
                    let grad = Gradient(colors: [
                        Color.white.opacity(0.85),
                        Color.white.opacity(0.35),
                        Color.clear
                    ])

                    context.fill(
                        Path(ellipseIn: rect),
                        with: .radialGradient(
                            grad,
                            center: CGPoint(x: rect.midX, y: rect.midY),
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

// MARK: - Rainfall Atmosphere (High-Speed Rain Streaks & Ambient Mist)

private struct RainfallAtmosphere: View {
    let heavy: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate

            Canvas { context, size in
                // Atmospheric ceiling gloom
                let cloudGloom = CGRect(x: -size.width * 0.2, y: -80, width: size.width * 1.4, height: size.height * 0.45)
                context.opacity = 0.35
                context.fill(
                    Path(ellipseIn: cloudGloom),
                    with: .radialGradient(
                        Gradient(colors: [Color.black.opacity(0.7), Color.clear]),
                        center: CGPoint(x: cloudGloom.midX, y: cloudGloom.midY),
                        startRadius: 10,
                        endRadius: cloudGloom.width * 0.5
                    )
                )

                // High-velocity streaks
                let count = heavy ? 120 : 75
                let tiltAngle: CGFloat = 0.14 // Natural wind drift

                for i in 0..<count {
                    let seed = Double(i) * 47.7
                    let speed = heavy ? (680.0 + Double(i % 10) * 45.0) : (520.0 + Double(i % 8) * 35.0)
                    let length = CGFloat(18 + (i % 5) * 5)

                    let xOrigin = CGFloat((seed.truncatingRemainder(dividingBy: 1.0))) * size.width
                    let cycleH = size.height + length + 60
                    let yCurrent = (CGFloat(t * speed) + CGFloat(seed * 220)).truncatingRemainder(dividingBy: cycleH) - length
                    let xCurrent = xOrigin + (yCurrent * tiltAngle)

                    let opacity = 0.20 + Double(i % 5) * 0.08

                    var path = Path()
                    path.move(to: CGPoint(x: xCurrent, y: yCurrent))
                    path.addLine(to: CGPoint(x: xCurrent + (length * tiltAngle), y: yCurrent + length))

                    context.opacity = opacity
                    context.stroke(
                        path,
                        with: .color(Color(red: 0.85, green: 0.92, blue: 1.0)),
                        lineWidth: CGFloat(1.1 + Double(i % 3) * 0.4)
                    )
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Thunderstorm Atmosphere (Rain + Double-pulse Ambient Flash)

private struct ThunderstormAtmosphere: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate

            // Realistic multi-stroke lightning sequence
            let cycle = t.truncatingRemainder(dividingBy: 7.2)
            let isStroke1 = cycle > 5.10 && cycle < 5.22
            let isStroke2 = cycle > 5.30 && cycle < 5.48
            let flashOpacity = isStroke2 ? 0.42 : (isStroke1 ? 0.60 : 0.0)

            ZStack {
                RainfallAtmosphere(heavy: true)

                // Sky flash
                Color(red: 0.86, green: 0.90, blue: 1.0)
                    .opacity(flashOpacity)
                    .animation(.easeOut(duration: 0.1), value: flashOpacity)
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Snowfall Atmosphere (Harmonic Drifting Crystals)

private struct SnowfallAtmosphere: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate

            Canvas { context, size in
                let flakeCount = 60

                for i in 0..<flakeCount {
                    let seed = Double(i) * 39.8
                    let speed = 38.0 + Double(i % 6) * 14.0
                    let radius = CGFloat(1.6 + Double(i % 5) * 1.0)

                    let cycleH = size.height + 40
                    let yPos = (CGFloat(t * speed) + CGFloat(seed * 190)).truncatingRemainder(dividingBy: cycleH) - 20

                    // Wave sway
                    let amplitude = CGFloat(12 + (i % 4) * 8)
                    let frequency = 1.1 + Double(i % 3) * 0.35
                    let xBase = CGFloat((seed.truncatingRemainder(dividingBy: 1.0))) * size.width
                    let xPos = xBase + (sin(t * frequency + seed) * amplitude)

                    let opacity = 0.30 + Double(i % 4) * 0.14

                    context.opacity = opacity
                    context.fill(
                        Path(ellipseIn: CGRect(x: xPos - radius, y: yPos - radius, width: radius * 2, height: radius * 2)),
                        with: .color(.white)
                    )
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Night Starlight Atmosphere (Cosmic Bloom & Twinkling Constellations)

private struct NightStarlightAtmosphere: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate

            Canvas { context, size in
                // Subtle lunar glow
                let moonCenter = CGPoint(x: size.width * 0.82, y: size.height * 0.14)
                let moonRadius: CGFloat = 32
                let haloRadius: CGFloat = 160

                context.fill(
                    Path(ellipseIn: CGRect(x: moonCenter.x - haloRadius, y: moonCenter.y - haloRadius, width: haloRadius * 2, height: haloRadius * 2)),
                    with: .radialGradient(
                        Gradient(colors: [Color(red: 0.82, green: 0.88, blue: 1.0).opacity(0.18), Color.clear]),
                        center: moonCenter,
                        startRadius: 15,
                        endRadius: haloRadius
                    )
                )

                context.fill(
                    Path(ellipseIn: CGRect(x: moonCenter.x - moonRadius, y: moonCenter.y - moonRadius, width: moonRadius * 2, height: moonRadius * 2)),
                    with: .radialGradient(
                        Gradient(colors: [Color(red: 0.96, green: 0.98, blue: 1.0).opacity(0.88), Color(red: 0.82, green: 0.88, blue: 1.0).opacity(0.50)]),
                        center: moonCenter,
                        startRadius: 0,
                        endRadius: moonRadius
                    )
                )

                // Twinkling stars
                for i in 0..<36 {
                    let seed = Double(i) * 31.7
                    let xPos = (seed.truncatingRemainder(dividingBy: 1.0)) * size.width
                    let yPos = ((seed * 1.8).truncatingRemainder(dividingBy: 0.75)) * size.height

                    let pulseSpeed = 1.6 + Double(i % 4) * 0.6
                    let opacity = 0.20 + 0.60 * (0.5 + 0.5 * sin(t * pulseSpeed + seed))
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
