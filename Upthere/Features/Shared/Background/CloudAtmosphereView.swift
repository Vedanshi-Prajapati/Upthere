import SwiftUI
import os

// MARK: - Seeded Pseudo-Random Helper
// Deterministic hash for procedural generation — no randomness at runtime, fully reproducible.

func seededRandom(_ seed: Double) -> Double {
    let x = sin(seed * 127.1 + 311.7) * 43758.5453
    return x - x.rounded(.down)
}

func seededRandom2(_ seed: Double, _ offset: Double) -> Double {
    let x = sin(seed * 269.5 + offset * 183.3 + 571.1) * 21435.6789
    return x - x.rounded(.down)
}

// MARK: - Cloud Cluster Renderer
// Draws a single organic cloud by compositing many overlapping soft ellipses at varying positions,
// scales, and opacities. This breaks the "single oval" look completely.

func drawCloudCluster(
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

// MARK: - 3. Realistic Cloud Atmosphere (Cloudy / Partly Cloudy)
// Organic cloud formations built from multi-blob clusters. Each cloud is a composite of
// 8-12 overlapping ellipses with varying sizes, creating natural cumulus-like shapes.

struct RealisticCloudAtmosphere: View {
    let isOvercast: Bool

    @Environment(\.weatherClockTime) private var clockTime
    @Environment(\.weatherParticleScale) private var particleScale
    @Environment(\.isWeatherAnimationPaused) private var isPaused

    var body: some View {
        Canvas { context, size in
            let signpostID = WeatherSignpost.signposter.makeSignpostID()
            let state = WeatherSignpost.signposter.beginInterval("RealisticCloudAtmosphereDraw", id: signpostID)
            defer { WeatherSignpost.signposter.endInterval("RealisticCloudAtmosphereDraw", state) }

            let t = isPaused ? 0.0 : clockTime
            let baseCount = isOvercast ? 4 : 3
            let cloudCount = max(2, Int(Double(baseCount) * particleScale))
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
        .allowsHitTesting(false)
    }
}
