import SwiftUI

// MARK: - SkyBackgroundView

public struct SkyBackgroundView: View {
    public let scene: SkyScene
    public let isPaused: Bool

    public init(scene: SkyScene, isPaused: Bool = false) {
        self.scene = scene
        self.isPaused = isPaused
    }

    public var body: some View {
        ZStack {
            SkyCanvasView(scene: scene, isPaused: isPaused)
                .id(scene)
                .transition(.opacity)
        }
        .animation(.easeInOut(duration: 0.8), value: scene)
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

// MARK: - SkyCanvasView

struct SkyCanvasView: View {
    let scene: SkyScene
    let isPaused: Bool

    // Deterministically generated particles once per scene
    @State private var particles: [SkyParticle]

    init(scene: SkyScene, isPaused: Bool) {
        self.scene = scene
        self.isPaused = isPaused
        _particles = State(initialValue: SkyParticleGenerator.generate(for: scene))
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: isPaused)) { timeline in
            let time = isPaused ? 0.0 : timeline.date.timeIntervalSinceReferenceDate

            Canvas { context, size in
                guard size.width > 0, size.height > 0 else { return }

                // 1. Vertical Sky Gradient
                drawBackgroundGradient(context: context, size: size)

                // 2. Animated Elements (At most TWO element types per scene)
                drawSceneElements(context: context, size: size, time: time)

                // 3. Subtle top-to-bottom dark scrim (black 0 -> 25%)
                drawScrim(context: context, size: size)
            }
        }
        .ignoresSafeArea()
    }

    // MARK: - Gradient

    private func drawBackgroundGradient(context: GraphicsContext, size: CGSize) {
        let (top, bottom) = scene.gradientStops
        let gradient = Gradient(colors: [
            Color(red: top.r, green: top.g, blue: top.b),
            Color(red: bottom.r, green: bottom.g, blue: bottom.b)
        ])

        let rect = CGRect(origin: .zero, size: size)
        context.fill(
            Path(rect),
            with: .linearGradient(
                gradient,
                startPoint: CGPoint(x: size.width / 2, y: 0),
                endPoint: CGPoint(x: size.width / 2, y: size.height)
            )
        )
    }

    // MARK: - Scene Elements

    private func drawSceneElements(context: GraphicsContext, size: CGSize, time: TimeInterval) {
        switch scene {
        case .clearNight:
            drawStars(context: context, size: size, time: time)

        case .clearDay:
            drawSunGlowAndRays(context: context, size: size, time: time)

        case .partlyCloudy, .cloudy:
            drawClouds(context: context, size: size, time: time)

        case .fog, .haze:
            drawFogOrHaze(context: context, size: size, time: time)

        case .rain:
            drawCloudLayerAtTop(context: context, size: size, time: time)
            drawRain(context: context, size: size, time: time)

        case .thunderstorm:
            drawCloudLayerAtTop(context: context, size: size, time: time)
            drawRain(context: context, size: size, time: time)
            drawLightningFlash(context: context, size: size, time: time)

        case .snow:
            drawSnow(context: context, size: size, time: time)
        }
    }

    // MARK: - Element 1: Stars (clearNight)

    private func drawStars(context: GraphicsContext, size: CGSize, time: TimeInterval) {
        for star in particles {
            let cx = star.x * size.width + sin(time * 0.15 + star.phase) * 5.0
            let cy = star.y * size.height + cos(time * 0.10 + star.phase) * 3.5

            // Twinkle: opacity 0.62 - 0.88
            let twinkleFactor = 0.5 + 0.5 * sin(time * (1.8 + star.speedX) + star.phase)
            let opacity = 0.62 + (0.88 - 0.62) * twinkleFactor
            let r = star.size * 0.5

            let starRect = CGRect(x: cx - r, y: cy - r, width: 2 * r, height: 2 * r)
            context.fill(Path(ellipseIn: starRect), with: .color(Color.white.opacity(opacity)))
        }
    }

    // MARK: - Element 2: Sun Glow & Light Rays (clearDay)

    private func drawSunGlowAndRays(context: GraphicsContext, size: CGSize, time: TimeInterval) {
        let sunOrigin = CGPoint(x: size.width * 0.85, y: size.height * 0.08)
        let glowRadius = size.width * 0.30
        let glowAlpha = 0.32

        let glowGradient = Gradient(colors: [
            Color.white.opacity(glowAlpha),
            Color(red: 1.0, green: 0.95, blue: 0.80).opacity(glowAlpha * 0.5),
            Color.clear
        ])

        context.fill(
            Path(CGRect(origin: .zero, size: size)),
            with: .radialGradient(
                glowGradient,
                center: sunOrigin,
                startRadius: 0,
                endRadius: glowRadius
            )
        )

        // 2 light rays, opacity 0.10
        for ray in particles {
            let rayAlpha = 0.10
            let rayAngle = 2.15 + Double(ray.id) * 0.35 // Angle down-left in radians
            let length = ray.length
            let width = ray.size

            var rayPath = Path()
            rayPath.move(to: sunOrigin)

            let endPoint1 = CGPoint(
                x: sunOrigin.x + cos(rayAngle - 0.05) * length,
                y: sunOrigin.y + sin(rayAngle - 0.05) * length
            )
            let endPoint2 = CGPoint(
                x: sunOrigin.x + cos(rayAngle + 0.05) * length + width,
                y: sunOrigin.y + sin(rayAngle + 0.05) * length
            )

            rayPath.addLine(to: endPoint1)
            rayPath.addLine(to: endPoint2)
            rayPath.closeSubpath()

            let rayGradient = Gradient(colors: [
                Color.white.opacity(rayAlpha),
                Color.clear
            ])

            context.fill(
                rayPath,
                with: .linearGradient(
                    rayGradient,
                    startPoint: sunOrigin,
                    endPoint: endPoint1
                )
            )
        }
    }

    // MARK: - Element 3: Clouds (partlyCloudy, cloudy)

    private func drawClouds(context: GraphicsContext, size: CGSize, time: TimeInterval) {
        for cloud in particles {
            let cloudW = cloud.size * 2.2
            let cloudH = cloud.size * 0.9

            let span = size.width + cloudW * 2.0
            let rawX = cloud.x * size.width + time * cloud.speedX
            let cx = rawX.truncatingRemainder(dividingBy: span) - cloudW
            let cy = cloud.y * size.height + sin(time * 0.25 + cloud.phase) * 6.0

            // Cap cloud opacity behind the temperature text area (top-left third) to minimum of range (0.10)
            let isInTextArea = cx <= size.width / 3.0 && cy <= size.height / 3.0
            let cloudOpacity = isInTextArea ? min(cloud.opacity, 0.10) : cloud.opacity

            let cloudRect = CGRect(x: cx - cloudW / 2, y: cy - cloudH / 2, width: cloudW, height: cloudH)

            let cloudGradient = Gradient(colors: [
                Color.white.opacity(cloudOpacity),
                Color.white.opacity(cloudOpacity * 0.4),
                Color.clear
            ])

            context.fill(
                Path(ellipseIn: cloudRect),
                with: .radialGradient(
                    cloudGradient,
                    center: CGPoint(x: cx, y: cy),
                    startRadius: 0,
                    endRadius: cloudW / 2
                )
            )
        }
    }

    // MARK: - Element 4: Fog / Haze

    private func drawFogOrHaze(context: GraphicsContext, size: CGSize, time: TimeInterval) {
        let isHaze = (scene == .haze)
        let tintColor: Color = isHaze
            ? Color(red: 0.96, green: 0.88, blue: 0.76)
            : Color.white

        for band in particles {
            let bandH = band.size * 1.4
            let cy = band.y * size.height
            let drift = sin(time * 0.2 + band.phase) * 35.0
            let opacity = band.opacity

            let bandRect = CGRect(x: -40 + drift, y: cy - bandH / 2, width: size.width + 80, height: bandH)

            let bandGradient = Gradient(colors: [
                Color.clear,
                tintColor.opacity(opacity),
                Color.clear
            ])

            context.fill(
                Path(bandRect),
                with: .linearGradient(
                    bandGradient,
                    startPoint: CGPoint(x: size.width / 2, y: cy - bandH / 2),
                    endPoint: CGPoint(x: size.width / 2, y: cy + bandH / 2)
                )
            )
        }
    }

    // MARK: - Element 5: Rain

    private func drawRain(context: GraphicsContext, size: CGSize, time: TimeInterval) {
        // 60 thin falling diagonal lines (varying length, speed, opacity 0.34 to 0.58)
        for rain in particles {
            let dx = rain.length * 0.20 // ~12° diagonal tilt
            let dy = rain.length

            let spanY = size.height + dy + 40.0
            let spanX = size.width + dx + 40.0

            let rawY = rain.y * size.height + time * rain.speedY
            let rawX = rain.x * size.width + time * (rain.speedY * 0.20)

            let y = rawY.truncatingRemainder(dividingBy: spanY) - 20.0
            let x = rawX.truncatingRemainder(dividingBy: spanX) - 20.0

            var path = Path()
            path.move(to: CGPoint(x: x, y: y))
            path.addLine(to: CGPoint(x: x + dx, y: y + dy))

            context.stroke(
                path,
                with: .color(Color.white.opacity(rain.opacity)),
                lineWidth: 1.1
            )
        }
    }

    private func drawCloudLayerAtTop(context: GraphicsContext, size: CGSize, time: TimeInterval) {
        // Soft cloud band at top of rain/thunderstorm (opacity range 0.12 to 0.18)
        let topH = size.height * 0.24
        let topRect = CGRect(x: 0, y: 0, width: size.width, height: topH)
        let gradient = Gradient(colors: [
            Color.black.opacity(0.18),
            Color.black.opacity(0.12),
            Color.clear
        ])
        context.fill(
            Path(topRect),
            with: .linearGradient(
                gradient,
                startPoint: CGPoint(x: size.width / 2, y: 0),
                endPoint: CGPoint(x: size.width / 2, y: topH)
            )
        )
    }

    // MARK: - Element 6: Thunderstorm Flash

    private func drawLightningFlash(context: GraphicsContext, size: CGSize, time: TimeInterval) {
        // Rare soft full-screen flash (opacity 0 -> 0.25 -> 0 over 0.3s, every 6-12s)
        let period = 9.0
        let flashProgress = time.truncatingRemainder(dividingBy: period)

        if flashProgress < 0.30 {
            let flashAlpha: Double
            if flashProgress < 0.08 {
                flashAlpha = (flashProgress / 0.08) * 0.25
            } else {
                flashAlpha = ((0.30 - flashProgress) / 0.22) * 0.25
            }

            let fullRect = CGRect(origin: .zero, size: size)
            context.fill(Path(fullRect), with: .color(Color.white.opacity(flashAlpha)))
        }
    }

    // MARK: - Element 7: Snow

    private func drawSnow(context: GraphicsContext, size: CGSize, time: TimeInterval) {
        // 50 slow dots drifting down with slight sideways sway (opacity 0.38 to 0.78)
        for flake in particles {
            let sway = sin(time * (1.2 + flake.speedX) + flake.phase) * 16.0
            let spanY = size.height + flake.size + 20.0

            let rawY = flake.y * size.height + time * flake.speedY
            let y = rawY.truncatingRemainder(dividingBy: spanY) - 10.0
            let x = (flake.x * size.width + sway).truncatingRemainder(dividingBy: size.width)

            // Cap snow opacity behind the temperature text area (top-left third) to minimum of range (0.38)
            let isInTextArea = x <= size.width / 3.0 && y <= size.height / 3.0
            let flakeOpacity = isInTextArea ? min(flake.opacity, 0.38) : flake.opacity

            let r = flake.size * 0.5
            let flakeRect = CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r)

            context.fill(
                Path(ellipseIn: flakeRect),
                with: .color(Color.white.opacity(flakeOpacity))
            )
        }
    }

    // MARK: - Scrim

    private func drawScrim(context: GraphicsContext, size: CGSize) {
        // Subtle bottom scrim only — black 0% at top to 15% at bottom
        let scrimGradient = Gradient(colors: [
            Color.black.opacity(0.0),
            Color.black.opacity(0.15)
        ])
        let rect = CGRect(origin: .zero, size: size)
        context.fill(
            Path(rect),
            with: .linearGradient(
                scrimGradient,
                startPoint: CGPoint(x: size.width / 2, y: 0),
                endPoint: CGPoint(x: size.width / 2, y: size.height)
            )
        )
    }
}
