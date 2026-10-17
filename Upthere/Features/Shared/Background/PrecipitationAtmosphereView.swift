import SwiftUI

// MARK: - 4. Rain / Drizzle Atmosphere
// Layered rain with cloud mass overhead, multiple rain curtain depths, and wind-angled streaks.

struct RainAtmosphere: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { (timeline: TimelineViewDefaultContext) in
            RainCanvas(date: timeline.date)
        }
        .allowsHitTesting(false)
    }
}

struct RainCanvas: View {
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

struct ThunderstormAtmosphere: View {
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

struct SnowAtmosphere: View {
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
