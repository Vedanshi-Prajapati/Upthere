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

            // Layer 3: Extra contrast scrim for bright daytime skies
            // Ensures white text has ≥4.5:1 contrast on mid-blue backgrounds
            if type == .sunny || type == .partlyCloudy || type == .defaultTheme {
                LinearGradient(
                    colors: [
                        Color.black.opacity(0.40),  // Top — strong header protection
                        Color.black.opacity(0.18),  // Upper-mid
                        Color.black.opacity(0.06),  // Centre
                        Color.black.opacity(0.28)   // Bottom — card / footer protection
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

            // Layer 5: Delicate contrast veil to guarantee Liquid Glass clarity & contrast
            LinearGradient(
                colors: [
                    Color.black.opacity(colorScheme == .dark ? 0.20 : 0.10),
                    Color.clear,
                    Color.black.opacity(colorScheme == .dark ? 0.35 : 0.22)
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
            // Deep cerulean-blue at zenith — contrast-safe for white text
            return [
                .init(color: Color(red: 0.06, green: 0.24, blue: 0.58).opacity(1.0 + lightShift), location: 0.0),
                .init(color: Color(red: 0.10, green: 0.34, blue: 0.68), location: 0.40),
                .init(color: Color(red: 0.20, green: 0.48, blue: 0.78), location: 0.75),
                .init(color: Color(red: 0.32, green: 0.60, blue: 0.86), location: 1.0)
            ]
        case .partlyCloudy:
            // Slightly softer but still contrast-safe deep sky
            return [
                .init(color: Color(red: 0.07, green: 0.20, blue: 0.48), location: 0.0),
                .init(color: Color(red: 0.12, green: 0.28, blue: 0.56), location: 0.45),
                .init(color: Color(red: 0.22, green: 0.40, blue: 0.64), location: 0.80),
                .init(color: Color(red: 0.32, green: 0.52, blue: 0.72), location: 1.0)
            ]
        case .cloudy:
            // Soft diffuse overcast: muted atmospheric slate-gray/blue-gray palette
            return [
                .init(color: Color(red: 0.14, green: 0.18, blue: 0.25), location: 0.0),
                .init(color: Color(red: 0.20, green: 0.26, blue: 0.33), location: 0.45),
                .init(color: Color(red: 0.28, green: 0.34, blue: 0.41), location: 0.80),
                .init(color: Color(red: 0.35, green: 0.40, blue: 0.47), location: 1.0)
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

// MARK: - Seeded Pseudo-Random Helper
// Deterministic hash for procedural generation — no randomness at runtime, fully reproducible.

private func seededRandom(_ seed: Double) -> Double {
    let x = sin(seed * 127.1 + 311.7) * 43758.5453
    return x - x.rounded(.down)
}

private func seededRandom2(_ seed: Double, _ offset: Double) -> Double {
    let x = sin(seed * 269.5 + offset * 183.3 + 571.1) * 21435.6789
    return x - x.rounded(.down)
}

// MARK: - Cloud Cluster Renderer
// Draws a single organic cloud by compositing many overlapping soft ellipses at varying positions,
// scales, and opacities. This breaks the "single oval" look completely.

private func drawCloudCluster(
    in context: inout GraphicsContext,
    center: CGPoint,
    baseWidth: CGFloat,
    baseHeight: CGFloat,
    cloudColor: Color,
    overallOpacity: Double,
    seed: Double,
    time: Double
) {
    // Each cloud is 8-12 overlapping soft ellipses
    let blobCount = 8 + Int(seededRandom(seed + 99) * 5)

    // Breathing motion — very subtle scale pulse
    let breathe = 1.0 + 0.015 * sin(time * 0.18 + seed)

    for j in 0..<blobCount {
        let js = Double(j)
        let r1 = seededRandom(seed + js * 7.3)
        let r2 = seededRandom2(seed, js * 5.1)
        let r3 = seededRandom(seed + js * 13.7 + 200)
        let r4 = seededRandom2(seed + 50, js * 3.9)

        // Distribute blobs across the cloud body with natural clustering toward the center
        // Use gaussian-like falloff: most blobs near center, fewer at edges
        let spreadX = baseWidth * 0.55
        let spreadY = baseHeight * 0.45
        let offsetX = (r1 - 0.5) * 2.0 * spreadX * (0.6 + r3 * 0.4)
        let offsetY = (r2 - 0.5) * 2.0 * spreadY * (0.5 + r4 * 0.5)

        // Each blob has its own size — smaller blobs at the edges, larger near center
        let distFromCenter = sqrt(offsetX * offsetX / (spreadX * spreadX) + offsetY * offsetY / (spreadY * spreadY))
        let sizeFalloff = max(0.3, 1.0 - distFromCenter * 0.5)

        let blobW = baseWidth * (0.28 + r3 * 0.32) * sizeFalloff * breathe
        let blobH = baseHeight * (0.5 + r4 * 0.5) * sizeFalloff * breathe

        let blobX = center.x + offsetX - blobW * 0.5
        let blobY = center.y + offsetY - blobH * 0.5

        // Opacity variation — denser in the center, lighter at edges
        let blobOpacity = overallOpacity * (0.4 + 0.6 * sizeFalloff) * (0.7 + r1 * 0.3)
        context.opacity = max(0.02, blobOpacity)

        let rect = CGRect(x: blobX, y: blobY, width: blobW, height: blobH)
        context.fill(
            Path(ellipseIn: rect),
            with: .radialGradient(
                Gradient(colors: [
                    cloudColor.opacity(0.85),
                    cloudColor.opacity(0.40),
                    cloudColor.opacity(0.10),
                    Color.clear
                ]),
                center: CGPoint(x: rect.midX, y: rect.midY - blobH * 0.08),
                startRadius: 0,
                endRadius: max(blobW, blobH) * 0.52
            )
        )
    }
}

// MARK: - 2. Sunny / Clear Atmosphere
// Faint wispy cirrus streaks with turbulence, sun glow from outside the frame.

private struct SunnyAtmosphere: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate

            Canvas { context, size in
                // --- Wispy cirrus bands: each built from many thin overlapping streaks ---
                let bandCount = 4
                let driftSpeed: Double = 1.2

                for i in 0..<bandCount {
                    let baseSeed = Double(i) * 67.3
                    let bandY = size.height * (0.08 + CGFloat(i) * 0.12)
                    let cycleW = size.width * 2.2

                    // Each band is 5-7 thin overlapping wisps
                    let wispCount = 5 + Int(seededRandom(baseSeed + 10) * 3)

                    for w in 0..<wispCount {
                        let ws = Double(w)
                        let r1 = seededRandom(baseSeed + ws * 11.3)
                        let r2 = seededRandom2(baseSeed, ws * 9.7)
                        let r3 = seededRandom(baseSeed + ws * 23.1 + 100)

                        let wispWidth = size.width * (0.3 + r1 * 0.5)
                        let wispHeight: CGFloat = 12 + CGFloat(r2) * 35
                        let xShift = (r3 - 0.5) * size.width * 0.6

                        let xPos = (CGFloat(t * (driftSpeed + ws * 0.15)) + CGFloat(baseSeed * 30) + xShift)
                            .truncatingRemainder(dividingBy: cycleW) - wispWidth * 0.3
                        let yPos = bandY + CGFloat(r2 - 0.5) * 30

                        context.opacity = 0.025 + r3 * 0.025

                        let rect = CGRect(x: xPos, y: yPos, width: wispWidth, height: wispHeight)
                        context.fill(
                            Path(ellipseIn: rect),
                            with: .radialGradient(
                                Gradient(colors: [
                                    Color.white.opacity(0.50),
                                    Color.white.opacity(0.15),
                                    Color.clear
                                ]),
                                center: CGPoint(x: rect.midX, y: rect.midY),
                                startRadius: 0,
                                endRadius: wispWidth * 0.45
                            )
                        )
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - 3. Realistic Cloud Atmosphere (Cloudy / Partly Cloudy)
// Organic cloud formations built from multi-blob clusters. Each cloud is a composite of
// 8-12 overlapping ellipses with varying sizes, creating natural cumulus-like shapes.

private struct RealisticCloudAtmosphere: View {
    let isOvercast: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate

            Canvas { context, size in
                let cloudCount = isOvercast ? 6 : 4
                let baseSpeed: Double = isOvercast ? 1.8 : 1.2

                // Draw clouds back-to-front for natural layering
                for i in 0..<cloudCount {
                    let ci = Double(i)
                    let seed = ci * 47.3 + 123.4

                    // Cloud dimensions — wider than tall, with procedural variation
                    let widthFactor = 0.5 + seededRandom(seed + 1) * 0.4
                    let cloudWidth = size.width * widthFactor
                    let cloudHeight: CGFloat = 100 + CGFloat(seededRandom(seed + 2)) * 80

                    // Horizontal drift
                    let speed = baseSpeed + ci * 0.25 + seededRandom(seed + 3) * 0.6
                    let cycleDist = size.width + cloudWidth * 1.5
                    let xCenter = (CGFloat(t * speed) + CGFloat(seed * 55))
                        .truncatingRemainder(dividingBy: cycleDist) - cloudWidth * 0.25

                    // Vertical positioning — spread across the upper portion of the screen
                    let yBase = size.height * (0.02 + seededRandom(seed + 4) * 0.55)
                    // Slight vertical drift for organic feel
                    let yDrift = sin(t * 0.08 + ci * 2.0) * 6.0
                    let yCenter = yBase + yDrift

                    // Opacity — overcast is denser
                    let shift = 0.015 * sin(t * 0.12 + ci * 1.5)
                    let baseOpacity = isOvercast
                        ? (0.12 + seededRandom(seed + 5) * 0.08 + shift)
                        : (0.06 + seededRandom(seed + 5) * 0.06 + shift)

                    let cloudColor = isOvercast
                        ? Color(red: 0.85 + seededRandom(seed + 6) * 0.08,
                                green: 0.89 + seededRandom(seed + 7) * 0.06,
                                blue: 0.94 + seededRandom(seed + 8) * 0.04)
                        : Color(red: 0.95 + seededRandom(seed + 6) * 0.05,
                                green: 0.96 + seededRandom(seed + 7) * 0.04,
                                blue: 0.98)

                    drawCloudCluster(
                        in: &context,
                        center: CGPoint(x: xCenter, y: yCenter),
                        baseWidth: cloudWidth,
                        baseHeight: cloudHeight,
                        cloudColor: cloudColor,
                        overallOpacity: baseOpacity,
                        seed: seed,
                        time: t
                    )
                }

                // For overcast: add a thin uniform haze layer across the top
                if isOvercast {
                    context.opacity = 0.06 + 0.02 * sin(t * 0.1)
                    let hazeRect = CGRect(x: -20, y: -10, width: size.width + 40, height: size.height * 0.4)
                    context.fill(
                        Path(ellipseIn: hazeRect),
                        with: .radialGradient(
                            Gradient(colors: [
                                Color(red: 0.90, green: 0.93, blue: 0.96).opacity(0.5),
                                Color.clear
                            ]),
                            center: CGPoint(x: hazeRect.midX, y: hazeRect.minY),
                            startRadius: 0,
                            endRadius: size.width * 0.6
                        )
                    )
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - 4. Rain / Drizzle Atmosphere
// Layered rain with cloud mass overhead, multiple rain curtain depths, and wind-angled streaks.

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

            // --- Heavy overcast cloud mass at top ---
            for i in 0..<3 {
                let seed = Double(i) * 83.7
                let cw = size.width * (0.7 + seededRandom(seed) * 0.5)
                let ch: CGFloat = 90 + CGFloat(seededRandom(seed + 1)) * 60
                let cx = size.width * seededRandom(seed + 2) + CGFloat(t * 0.8).truncatingRemainder(dividingBy: size.width * 2) - size.width
                let cy = size.height * (-0.02 + seededRandom(seed + 3) * 0.15)

                drawCloudCluster(
                    in: &context,
                    center: CGPoint(x: cx, y: cy),
                    baseWidth: cw,
                    baseHeight: ch,
                    cloudColor: Color(red: 0.45, green: 0.50, blue: 0.58),
                    overallOpacity: 0.10,
                    seed: seed + 500,
                    time: t
                )
            }

            // --- Distant rain curtains (soft vertical washes) ---
            for curtainIndex in 0..<4 {
                let curtainSeed = Double(curtainIndex) * 41.5 + 17.3
                let curtainX = CGFloat(seededRandom(curtainSeed)) * size.width
                let curtainWidth: CGFloat = 100 + CGFloat(seededRandom(curtainSeed + 1)) * 80
                let densityMod = 0.035 + 0.025 * sin(t * 0.25 + curtainSeed)
                context.opacity = densityMod

                let curtainRect = CGRect(
                    x: curtainX - curtainWidth * 0.5,
                    y: size.height * 0.10,
                    width: curtainWidth,
                    height: size.height * 0.70
                )
                context.fill(
                    Path(curtainRect),
                    with: .linearGradient(
                        Gradient(colors: [
                            Color.clear,
                            Color(red: 0.50, green: 0.58, blue: 0.70).opacity(0.35),
                            Color(red: 0.50, green: 0.58, blue: 0.70).opacity(0.20),
                            Color.clear
                        ]),
                        startPoint: CGPoint(x: curtainRect.midX, y: curtainRect.minY),
                        endPoint: CGPoint(x: curtainRect.midX, y: curtainRect.maxY)
                    )
                )
            }

            // --- Rain streaks at multiple depths ---
            let dropCount = 55
            let windAngle: CGFloat = 0.10 // Slight wind tilt

            for i in 0..<dropCount {
                let seed = Double(i) * 31.7
                let depthLayer = i % 3 // 0 = far, 1 = mid, 2 = near

                let speed: Double
                let length: CGFloat
                let lineW: CGFloat
                let baseOpacity: Double

                switch depthLayer {
                case 0:
                    speed = 320.0 + seededRandom(seed) * 40
                    length = CGFloat(8 + Int(seededRandom(seed + 1) * 6))
                    lineW = 0.5
                    baseOpacity = 0.08
                case 2:
                    speed = 520.0 + seededRandom(seed) * 60
                    length = CGFloat(20 + Int(seededRandom(seed + 1) * 10))
                    lineW = 1.5
                    baseOpacity = 0.22
                default:
                    speed = 420.0 + seededRandom(seed) * 50
                    length = CGFloat(14 + Int(seededRandom(seed + 1) * 8))
                    lineW = 1.0
                    baseOpacity = 0.14
                }

                let xOrigin = CGFloat(seededRandom(seed + 2)) * size.width
                let cycleH = size.height + length + 40
                let yPos = (CGFloat(t * speed) + CGFloat(seed * 180)).truncatingRemainder(dividingBy: cycleH) - length
                let windSway = sin(t * 0.5 + seed * 0.1) * 2.0
                let xPos = xOrigin + (yPos * windAngle) + windSway

                context.opacity = baseOpacity + seededRandom(seed + 3) * 0.06

                var path = Path()
                path.move(to: CGPoint(x: xPos, y: yPos))
                path.addLine(to: CGPoint(x: xPos + (length * windAngle), y: yPos + length))

                context.stroke(
                    path,
                    with: .color(Color(red: 0.82, green: 0.90, blue: 1.0).opacity(0.9)),
                    lineWidth: lineW
                )
            }
        }
    }
}

// MARK: - 5. Thunderstorm Atmosphere
// Deep storm with dense cloud clusters, driving rain, and multi-point sheet lightning.

private struct ThunderstormAtmosphere: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate

            // Multi-pattern lightning: two independent cycles for more natural feel
            let cycle1 = t.truncatingRemainder(dividingBy: 9.5)
            let cycle2 = t.truncatingRemainder(dividingBy: 13.2)

            let flash1a = cycle1 > 6.80 && cycle1 < 6.90
            let flash1b = cycle1 > 7.00 && cycle1 < 7.14
            let flash2a = cycle2 > 4.10 && cycle2 < 4.22

            let flashIntensity1 = flash1b ? 0.30 : (flash1a ? 0.45 : 0.0)
            let flashIntensity2 = flash2a ? 0.25 : 0.0

            ZStack {
                // Storm cloud mass + rain
                RainAtmosphere()

                // Lightning flashes at different positions
                if flashIntensity1 > 0 {
                    RadialGradient(
                        colors: [
                            Color(red: 0.80, green: 0.85, blue: 1.0).opacity(flashIntensity1),
                            Color(red: 0.60, green: 0.68, blue: 0.88).opacity(flashIntensity1 * 0.4),
                            Color.clear
                        ],
                        center: UnitPoint(x: 0.35, y: 0.18),
                        startRadius: 30,
                        endRadius: 450
                    )
                    .blendMode(.screen)
                }

                if flashIntensity2 > 0 {
                    RadialGradient(
                        colors: [
                            Color(red: 0.75, green: 0.80, blue: 0.95).opacity(flashIntensity2),
                            Color(red: 0.55, green: 0.62, blue: 0.82).opacity(flashIntensity2 * 0.3),
                            Color.clear
                        ],
                        center: UnitPoint(x: 0.72, y: 0.12),
                        startRadius: 20,
                        endRadius: 380
                    )
                    .blendMode(.screen)
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - 6. Snow Atmosphere
// Depth-layered snowflakes with varying sizes, gentle sway, and soft glow on larger flakes.

private struct SnowAtmosphere: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate

            Canvas { context, size in
                // Three depth layers of snowflakes
                let flakeCount = 35

                for i in 0..<flakeCount {
                    let seed = Double(i) * 43.1
                    let depthLayer = i % 3 // 0 = far, 1 = mid, 2 = near

                    let speed: Double
                    let radius: CGFloat
                    let baseOpacity: Double
                    let swayAmplitude: Double
                    let swayFreq: Double

                    switch depthLayer {
                    case 0: // Far — small, slow, dim
                        speed = 16.0 + seededRandom(seed) * 8
                        radius = 0.8 + CGFloat(seededRandom(seed + 1)) * 0.4
                        baseOpacity = 0.12 + seededRandom(seed + 2) * 0.08
                        swayAmplitude = 3.0
                        swayFreq = 0.5 + seededRandom(seed + 3) * 0.3
                    case 2: // Near — larger, faster, brighter
                        speed = 40.0 + seededRandom(seed) * 15
                        radius = 2.0 + CGFloat(seededRandom(seed + 1)) * 1.5
                        baseOpacity = 0.45 + seededRandom(seed + 2) * 0.15
                        swayAmplitude = 14.0
                        swayFreq = 0.6 + seededRandom(seed + 3) * 0.4
                    default: // Mid
                        speed = 28.0 + seededRandom(seed) * 10
                        radius = 1.2 + CGFloat(seededRandom(seed + 1)) * 0.8
                        baseOpacity = 0.28 + seededRandom(seed + 2) * 0.12
                        swayAmplitude = 8.0
                        swayFreq = 0.55 + seededRandom(seed + 3) * 0.35
                    }

                    let cycleH = size.height + 40
                    let yPos = (CGFloat(t * speed) + CGFloat(seed * 160)).truncatingRemainder(dividingBy: cycleH) - 20

                    let xBase = CGFloat(seededRandom(seed + 10)) * size.width
                    let xPos = xBase + sin(t * swayFreq + seed) * swayAmplitude

                    // Soft glow on larger (nearer) flakes
                    if depthLayer == 2 && radius > 2.5 {
                        context.opacity = baseOpacity * 0.3
                        let glowR = radius * 3.0
                        context.fill(
                            Path(ellipseIn: CGRect(x: xPos - glowR, y: yPos - glowR, width: glowR * 2, height: glowR * 2)),
                            with: .radialGradient(
                                Gradient(colors: [Color.white.opacity(0.4), Color.clear]),
                                center: CGPoint(x: xPos, y: yPos),
                                startRadius: 0,
                                endRadius: glowR
                            )
                        )
                    }

                    context.opacity = baseOpacity
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
// Deep sky with sparse stars of varying color temperature and gentle scintillation,
// plus a faint Milky Way band.

private struct ClearNightAtmosphere: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 15.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate

            Canvas { context, size in
                // --- Faint Milky Way band ---
                context.opacity = 0.04
                let bandWidth = size.width * 0.35
                let bandRect = CGRect(
                    x: size.width * 0.25,
                    y: -size.height * 0.1,
                    width: bandWidth,
                    height: size.height * 0.8
                )
                context.fill(
                    Path(ellipseIn: bandRect),
                    with: .radialGradient(
                        Gradient(colors: [
                            Color(red: 0.70, green: 0.75, blue: 0.90).opacity(0.5),
                            Color(red: 0.50, green: 0.55, blue: 0.75).opacity(0.2),
                            Color.clear
                        ]),
                        center: CGPoint(x: bandRect.midX, y: bandRect.midY),
                        startRadius: 10,
                        endRadius: bandWidth * 0.5
                    )
                )

                // --- Stars with color temperature variation ---
                let starCount = 30

                for i in 0..<starCount {
                    let seed = Double(i) * 29.8
                    let xPos = seededRandom(seed) * size.width
                    let yPos = seededRandom(seed + 50) * size.height * 0.75 // Upper sky bias

                    // Star color: warm white, cool blue-white, or pale gold
                    let colorSeed = seededRandom(seed + 100)
                    let starColor: Color
                    if colorSeed < 0.4 {
                        starColor = Color(red: 1.0, green: 0.98, blue: 0.94) // Warm white
                    } else if colorSeed < 0.75 {
                        starColor = Color(red: 0.88, green: 0.92, blue: 1.0) // Cool blue-white
                    } else {
                        starColor = Color(red: 1.0, green: 0.95, blue: 0.80) // Pale gold
                    }

                    // Scintillation with varying speeds
                    let twinkleSpeed = 0.6 + seededRandom(seed + 200) * 0.8
                    let twinklePhase = seededRandom(seed + 300) * .pi * 2
                    let twinkle = 0.15 + 0.40 * (0.5 + 0.5 * sin(t * twinkleSpeed + twinklePhase))

                    let isBright = seededRandom(seed + 400) > 0.8
                    let r: CGFloat = isBright ? (1.1 + CGFloat(seededRandom(seed + 500)) * 0.5) : (0.6 + CGFloat(seededRandom(seed + 500)) * 0.3)

                    // Soft glow around bright stars
                    if isBright {
                        context.opacity = twinkle * 0.25
                        let glowR = r * 4.0
                        context.fill(
                            Path(ellipseIn: CGRect(x: xPos - glowR, y: yPos - glowR, width: glowR * 2, height: glowR * 2)),
                            with: .radialGradient(
                                Gradient(colors: [starColor.opacity(0.4), Color.clear]),
                                center: CGPoint(x: xPos, y: yPos),
                                startRadius: 0,
                                endRadius: glowR
                            )
                        )
                    }

                    context.opacity = twinkle
                    context.fill(
                        Path(ellipseIn: CGRect(x: xPos - r, y: yPos - r, width: r * 2, height: r * 2)),
                        with: .color(starColor)
                    )
                }
            }
        }
        .allowsHitTesting(false)
    }
}
