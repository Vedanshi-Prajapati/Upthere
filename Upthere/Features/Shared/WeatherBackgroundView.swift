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
            RealisticSkyCanvas(type: type)

            // Layer 2: Subtle, restrained atmospheric motion layer
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

            // Layer 3: Contrast and mood adjustment based on active Dark/Light mode
            if colorScheme == .dark {
                // Dark mode deep atmospheric tint
                Color.black.opacity(0.32)
                    .allowsHitTesting(false)
            }

            // Layer 4: Delicate contrast veil to guarantee Liquid Glass clarity & contrast
            LinearGradient(
                colors: [
                    Color.black.opacity(colorScheme == .dark ? 0.20 : 0.08),
                    Color.clear,
                    Color.black.opacity(colorScheme == .dark ? 0.35 : 0.20)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)
        }
        .ignoresSafeArea()
    }
}

// MARK: - 1. Realistic Sky Canvas (Natural color temperature & atmospheric perspective)

private struct RealisticSkyCanvas: View {
    let type: WeatherVisualType

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 15.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            // Barely perceptible natural light breathing (period ~ 24s)
            let lightShift = 0.03 * sin(t * (2.0 * .pi / 24.0))

            GeometryReader { proxy in
                let w = proxy.size.width
                let h = proxy.size.height

                ZStack {
                    // True atmospheric sky gradient: zenith (top) -> horizon (bottom)
                    LinearGradient(
                        stops: skyStops(for: type, lightShift: lightShift),
                        startPoint: .top,
                        endPoint: .bottom
                    )

                    // Distant sunlight bleed from outside the upper-trailing frame (Sunny / Clear)
                    if type == .sunny {
                        RadialGradient(
                            colors: [
                                Color(red: 1.0, green: 0.96, blue: 0.88).opacity(0.22 + lightShift),
                                Color(red: 0.85, green: 0.92, blue: 1.0).opacity(0.08),
                                Color.clear
                            ],
                            center: UnitPoint(x: 1.15, y: -0.10), // Outside the frame
                            startRadius: 80,
                            endRadius: max(w, h) * 0.95
                        )
                    }

                    // Soft ambient horizon haze (for Cloudy, Rain, Snow)
                    if type == .cloudy || type == .rainy || type == .snowy {
                        LinearGradient(
                            colors: [
                                Color.clear,
                                horizonHazeColor(for: type).opacity(0.18)
                            ],
                            startPoint: .center,
                            endPoint: .bottom
                        )
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 1.4), value: type)
        .allowsHitTesting(false)
    }

    private func skyStops(for type: WeatherVisualType, lightShift: Double) -> [Gradient.Stop] {
        switch type {
        case .sunny:
            // Natural blue sky: rich atmospheric cerulean at zenith tapering to soft warm horizon
            return [
                .init(color: Color(red: 0.12, green: 0.38, blue: 0.76).opacity(1.0 + lightShift), location: 0.0),
                .init(color: Color(red: 0.22, green: 0.52, blue: 0.86), location: 0.45),
                .init(color: Color(red: 0.42, green: 0.68, blue: 0.92), location: 0.82),
                .init(color: Color(red: 0.58, green: 0.78, blue: 0.95), location: 1.0)
            ]
        case .partlyCloudy:
            // Slightly softer natural daytime sky
            return [
                .init(color: Color(red: 0.14, green: 0.32, blue: 0.62), location: 0.0),
                .init(color: Color(red: 0.24, green: 0.44, blue: 0.72), location: 0.50),
                .init(color: Color(red: 0.40, green: 0.58, blue: 0.80), location: 0.85),
                .init(color: Color(red: 0.52, green: 0.68, blue: 0.86), location: 1.0)
            ]
        case .cloudy:
            // Soft diffuse overcast: cool slate gray-blue with subtle brightness variation
            return [
                .init(color: Color(red: 0.16, green: 0.23, blue: 0.35), location: 0.0),
                .init(color: Color(red: 0.25, green: 0.33, blue: 0.44), location: 0.45),
                .init(color: Color(red: 0.36, green: 0.43, blue: 0.52), location: 0.80),
                .init(color: Color(red: 0.45, green: 0.50, blue: 0.58), location: 1.0)
            ]
        case .rainy:
            // Naturally overcast blue-gray sky with atmospheric depth
            return [
                .init(color: Color(red: 0.10, green: 0.18, blue: 0.30), location: 0.0),
                .init(color: Color(red: 0.16, green: 0.25, blue: 0.37), location: 0.45),
                .init(color: Color(red: 0.24, green: 0.32, blue: 0.44), location: 0.80),
                .init(color: Color(red: 0.30, green: 0.38, blue: 0.48), location: 1.0)
            ]
        case .thunderstorm:
            // Deep, dense storm canopy: heavy slate-indigo with dark cloud weight
            return [
                .init(color: Color(red: 0.06, green: 0.08, blue: 0.16), location: 0.0),
                .init(color: Color(red: 0.10, green: 0.13, blue: 0.22), location: 0.45),
                .init(color: Color(red: 0.15, green: 0.18, blue: 0.28), location: 0.80),
                .init(color: Color(red: 0.20, green: 0.22, blue: 0.32), location: 1.0)
            ]
        case .snowy:
            // Muted, cold sky with soft icy haze
            return [
                .init(color: Color(red: 0.18, green: 0.27, blue: 0.42), location: 0.0),
                .init(color: Color(red: 0.28, green: 0.38, blue: 0.52), location: 0.45),
                .init(color: Color(red: 0.42, green: 0.52, blue: 0.65), location: 0.82),
                .init(color: Color(red: 0.55, green: 0.64, blue: 0.74), location: 1.0)
            ]
        case .night:
            // Deep navy sky with natural darkening gradient
            return [
                .init(color: Color(red: 0.03, green: 0.04, blue: 0.11), location: 0.0),
                .init(color: Color(red: 0.05, green: 0.08, blue: 0.18), location: 0.50),
                .init(color: Color(red: 0.08, green: 0.12, blue: 0.24), location: 0.85),
                .init(color: Color(red: 0.10, green: 0.15, blue: 0.28), location: 1.0)
            ]
        case .defaultTheme:
            return [
                .init(color: Color(red: 0.12, green: 0.32, blue: 0.68), location: 0.0),
                .init(color: Color(red: 0.22, green: 0.48, blue: 0.80), location: 0.50),
                .init(color: Color(red: 0.38, green: 0.64, blue: 0.90), location: 1.0)
            ]
        }
    }

    private func horizonHazeColor(for type: WeatherVisualType) -> Color {
        switch type {
        case .cloudy: return Color(red: 0.50, green: 0.54, blue: 0.60)
        case .rainy: return Color(red: 0.35, green: 0.42, blue: 0.50)
        case .snowy: return Color(red: 0.65, green: 0.72, blue: 0.80)
        default: return Color.white.opacity(0.10)
        }
    }
}

// MARK: - 2. Sunny / Clear Atmosphere
// Faint wispy cirrus clouds drifting extremely slowly, sunlight coming from outside the frame.

private struct SunnyAtmosphere: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 15.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate

            Canvas { context, size in
                // Faint wispy cirrus bands drifting at ~ 1.5 pt/sec
                let speed: Double = 1.6
                let cycleWidth = size.width * 1.8

                for i in 0..<3 {
                    let seed = Double(i) * 54.2
                    let width = size.width * (1.2 + CGFloat(i) * 0.3)
                    let height: CGFloat = 65 + CGFloat(i * 20)
                    let xOffset = (CGFloat(t * speed) + CGFloat(seed * 40)).truncatingRemainder(dividingBy: cycleWidth) - width * 0.4
                    let yPos = size.height * (0.12 + CGFloat(i) * 0.14)

                    // Whispering soft opacity: 3% to 6%
                    context.opacity = 0.045 + Double(i % 2) * 0.02

                    let rect = CGRect(x: xOffset, y: yPos, width: width, height: height)
                    let grad = Gradient(colors: [
                        Color.white.opacity(0.60),
                        Color.white.opacity(0.18),
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

// MARK: - 3. Realistic Cloud Atmosphere (Cloudy / Partly Cloudy)
// Real cloud formations with soft edges, natural variations in density, and diffuse light. No circular blobs.

private struct RealisticCloudAtmosphere: View {
    let isOvercast: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate

            Canvas { context, size in
                let cloudCount = isOvercast ? 5 : 3
                let baseSpeed: Double = isOvercast ? 2.2 : 1.8 // Extremely slow, graceful evolution

                for i in 0..<cloudCount {
                    let width = size.width * (1.3 + CGFloat(i % 3) * 0.3)
                    let height: CGFloat = 160 + CGFloat(i * 30)
                    let cycleDist = size.width + width

                    let xOffset = (CGFloat(t * (baseSpeed + Double(i) * 0.4)) + CGFloat(i * 260)).truncatingRemainder(dividingBy: cycleDist) - width * 0.5
                    let yPos = size.height * (0.04 + CGFloat(i) * 0.15)

                    // Subtle natural brightness shifts
                    let shift = 0.02 * sin(t * 0.15 + Double(i))
                    let opacity = isOvercast ? (0.14 + Double(i % 3) * 0.04 + shift) : (0.08 + Double(i % 2) * 0.03 + shift)

                    context.opacity = max(0.04, opacity)

                    // Layered cloud mass with diffuse edges
                    let rect = CGRect(x: xOffset, y: yPos, width: width, height: height)
                    let cloudColor = isOvercast ? Color(red: 0.88, green: 0.92, blue: 0.96) : Color.white

                    context.fill(
                        Path(ellipseIn: rect),
                        with: .radialGradient(
                            Gradient(colors: [
                                cloudColor.opacity(0.70),
                                cloudColor.opacity(0.30),
                                Color.clear
                            ]),
                            center: CGPoint(x: rect.midX, y: rect.midY),
                            startRadius: 10,
                            endRadius: width * 0.48
                        )
                    )
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - 4. Rain / Drizzle Atmosphere
// Fine rain moving at a slight angle with distant rain curtains and soft atmospheric haze.

private struct RainAtmosphere: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { (timeline: TimelineViewDefaultContext) in
            RainCanvas(date: timeline.date)
        }
        .allowsHitTesting(false)
    }
}

private struct RainCanvas: View {
    let date: Date

    var body: some View {
        Canvas { context, size in
            let t = date.timeIntervalSinceReferenceDate

            // Distant rain curtains
            for curtainIndex in 0..<3 {
                let curtainSeed = Double(curtainIndex) * 41.5
                let curtainX = CGFloat((curtainSeed.truncatingRemainder(dividingBy: 1.0))) * size.width
                let densityMod = 0.04 + 0.03 * sin(t * 0.3 + curtainSeed)
                context.opacity = densityMod

                let curtainRect = CGRect(x: curtainX - 60, y: size.height * 0.15, width: 140, height: size.height * 0.65)
                context.fill(
                    Path(curtainRect),
                    with: .linearGradient(
                        Gradient(colors: [Color.clear, Color(red: 0.50, green: 0.60, blue: 0.72).opacity(0.4), Color.clear]),
                        startPoint: CGPoint(x: curtainRect.midX, y: curtainRect.minY),
                        endPoint: CGPoint(x: curtainRect.midX, y: curtainRect.maxY)
                    )
                )
            }

            // Fine rain streaks
            let dropCount = 45
            let tiltAngle: CGFloat = 0.08

            for i in 0..<dropCount {
                let seed = Double(i) * 31.7
                let speed = 440.0 + Double(i % 6) * 35.0
                let length = CGFloat(14 + (i % 4) * 4)

                let xOrigin = CGFloat((seed.truncatingRemainder(dividingBy: 1.0))) * size.width
                let cycleH = size.height + length + 30
                let yPos = (CGFloat(t * speed) + CGFloat(seed * 180)).truncatingRemainder(dividingBy: cycleH) - length
                let xPos = xOrigin + (yPos * tiltAngle)

                let opacity = 0.14 + Double(i % 4) * 0.05
                context.opacity = opacity

                var path = Path()
                path.move(to: CGPoint(x: xPos, y: yPos))
                path.addLine(to: CGPoint(x: xPos + (length * tiltAngle), y: yPos + length))

                context.stroke(
                    path,
                    with: .color(Color(red: 0.88, green: 0.94, blue: 1.0)),
                    lineWidth: 1.0
                )
            }
        }
    }
}

// MARK: - 5. Thunderstorm Atmosphere
// Deep, dense storm clouds with realistic depth and occasional distant lightning illuminating clouds.

private struct ThunderstormAtmosphere: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate

            // Occasional distant sheet lightning (every ~9.5s with realistic quick double-flicker)
            let cycle = t.truncatingRemainder(dividingBy: 9.5)
            let isFlash1 = cycle > 6.80 && cycle < 6.92
            let isFlash2 = cycle > 7.02 && cycle < 7.18
            let flashIntensity = isFlash2 ? 0.35 : (isFlash1 ? 0.50 : 0.0)

            ZStack {
                // Dense storm cloud movement + rain
                RainAtmosphere()

                // Distant cloud-illuminating illumination (no harsh white flash, but natural internal cloud glow)
                if flashIntensity > 0 {
                    RadialGradient(
                        colors: [
                            Color(red: 0.80, green: 0.85, blue: 1.0).opacity(flashIntensity),
                            Color(red: 0.60, green: 0.68, blue: 0.88).opacity(flashIntensity * 0.5),
                            Color.clear
                        ],
                        center: UnitPoint(x: 0.40, y: 0.22),
                        startRadius: 40,
                        endRadius: 500
                    )
                    .blendMode(.screen)
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - 6. Snow Atmosphere
// A muted cold sky with sparse, depth-aware snowflakes drifting gently with atmospheric haze.

private struct SnowAtmosphere: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate

            Canvas { context, size in
                // Sparse snowflakes: ~ 28 total for calm elegance
                let flakeCount = 28

                for i in 0..<flakeCount {
                    let seed = Double(i) * 43.1
                    let isDistant = (i % 3) == 0

                    let speed = isDistant ? 22.0 : 34.0 + Double(i % 4) * 8.0 // px/sec
                    let radius: CGFloat = isDistant ? 1.0 : CGFloat(1.5 + Double(i % 3) * 0.7)

                    let cycleH = size.height + 30
                    let yPos = (CGFloat(t * speed) + CGFloat(seed * 160)).truncatingRemainder(dividingBy: cycleH) - 15

                    // Very subtle sway
                    let amplitude = isDistant ? 5.0 : 10.0
                    let frequency = 0.8 + Double(i % 3) * 0.25
                    let xBase = CGFloat((seed.truncatingRemainder(dividingBy: 1.0))) * size.width
                    let xPos = xBase + (sin(t * frequency + seed) * amplitude)

                    let opacity = isDistant ? 0.20 : 0.40 + Double(i % 3) * 0.12
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

// MARK: - 7. Clear Night Atmosphere
// Deep navy sky with natural darkening gradient, small number of faint stars, subtle scintillation.

private struct ClearNightAtmosphere: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 15.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate

            Canvas { context, size in
                // Sparse realistic stars (~22 faint stars, no big moon)
                let starCount = 22

                for i in 0..<starCount {
                    let seed = Double(i) * 29.8
                    let xPos = (seed.truncatingRemainder(dividingBy: 1.0)) * size.width
                    let yPos = ((seed * 1.5).truncatingRemainder(dividingBy: 0.65)) * size.height // Focused in upper sky

                    // Very subtle star scintillation (gentle twinkle)
                    let twinkleSpeed = 0.8 + Double(i % 4) * 0.35
                    let twinkle = 0.18 + 0.35 * (0.5 + 0.5 * sin(t * twinkleSpeed + seed))
                    let r: CGFloat = (i % 5 == 0) ? 1.2 : 0.8

                    context.opacity = twinkle
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
