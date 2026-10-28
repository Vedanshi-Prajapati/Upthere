import Testing
import SwiftUI
import CoreGraphics
import os
@testable import Upthere

// MARK: - Composited Scene Measurement & Renderer

struct CompositedSceneMeasurement {
    let scene: SkyScene
    let sampledLuminance: Double
    let contrastRatio: Double
    let opacityCapped: Bool
}

enum CompositedSceneRenderer {
    static func renderAndMeasure(
        scene: SkyScene,
        size: CGSize = CGSize(width: 390, height: 844),
        capOpacityInTextArea: Bool = true
    ) -> CompositedSceneMeasurement {
        let width = Int(size.width)
        let height = Int(size.height)
        let bytesPerRow = width * 4
        let colorSpace = CGColorSpaceCreateDeviceRGB()

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            fatalError("Could not create CGContext for scene rendering")
        }

        // Top-down coordinates (y = 0 at top)
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1.0, y: -1.0)

        // 1. Vertical Gradient
        let stops = scene.gradientStops
        let colors = [
            CGColor(srgbRed: CGFloat(stops.top.r), green: CGFloat(stops.top.g), blue: CGFloat(stops.top.b), alpha: 1.0),
            CGColor(srgbRed: CGFloat(stops.bottom.r), green: CGFloat(stops.bottom.g), blue: CGFloat(stops.bottom.b), alpha: 1.0)
        ] as CFArray
        let colorLocations: [CGFloat] = [0.0, 1.0]
        if let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: colorLocations) {
            context.drawLinearGradient(
                gradient,
                start: CGPoint(x: CGFloat(width) / 2.0, y: 0),
                end: CGPoint(x: CGFloat(width) / 2.0, y: CGFloat(height)),
                options: []
            )
        }

        let particles = SkyParticleGenerator.generate(for: scene, seed: 42)
        var opacityCapped = false

        // 2. Elements at Maximum Opacity
        switch scene {
        case .clearDay:
            // Glare: opacity 0.32, centred top-right at (0.85w, 0.08h), radius 0.30w
            let sunCenter = CGPoint(x: CGFloat(width) * 0.85, y: CGFloat(height) * 0.08)
            let glowRadius = CGFloat(width) * 0.30
            let glareColors = [
                CGColor(srgbRed: 1.0, green: 1.0, blue: 1.0, alpha: 0.32),
                CGColor(srgbRed: 1.0, green: 0.95, blue: 0.80, alpha: 0.16),
                CGColor(srgbRed: 1.0, green: 1.0, blue: 1.0, alpha: 0.0)
            ] as CFArray
            if let glareGrad = CGGradient(colorsSpace: colorSpace, colors: glareColors, locations: [0.0, 0.5, 1.0]) {
                context.drawRadialGradient(
                    glareGrad,
                    startCenter: sunCenter,
                    startRadius: 0,
                    endCenter: sunCenter,
                    endRadius: glowRadius,
                    options: []
                )
            }
            // 2 rays, opacity 0.10
            for (idx, ray) in particles.prefix(2).enumerated() {
                context.saveGState()
                context.setStrokeColor(CGColor(srgbRed: 1.0, green: 1.0, blue: 1.0, alpha: 0.10))
                context.setLineWidth(CGFloat(ray.size))
                let angle = 2.15 + Double(idx) * 0.35
                let length = CGFloat(ray.length)
                context.move(to: sunCenter)
                context.addLine(to: CGPoint(x: sunCenter.x + cos(angle) * length, y: sunCenter.y + sin(angle) * length))
                context.strokePath()
                context.restoreGState()
            }

        case .clearNight:
            // 40 stars at maximum twinkle opacity 0.88
            context.setFillColor(CGColor(srgbRed: 1.0, green: 1.0, blue: 1.0, alpha: 0.88))
            for star in particles {
                let cx = CGFloat(star.x) * CGFloat(width)
                let cy = CGFloat(star.y) * CGFloat(height)
                let r = CGFloat(star.size * 0.5)
                context.fillEllipse(in: CGRect(x: cx - r, y: cy - r, width: 2 * r, height: 2 * r))
            }

        case .cloudy, .partlyCloudy:
            // Clouds: max opacity 0.18, capped to 0.10 in text area
            for cloud in particles {
                let cloudW = CGFloat(cloud.size * 2.2)
                let cloudH = CGFloat(cloud.size * 0.9)
                let cx = CGFloat(cloud.x) * CGFloat(width)
                let cy = CGFloat(cloud.y) * CGFloat(height)
                let inTextArea = cx <= CGFloat(width) / 3.0 && cy <= CGFloat(height) / 3.0
                let alpha: CGFloat
                if inTextArea && capOpacityInTextArea {
                    alpha = 0.10
                    opacityCapped = true
                } else {
                    alpha = 0.18
                }
                let cloudColors = [
                    CGColor(srgbRed: 1.0, green: 1.0, blue: 1.0, alpha: alpha),
                    CGColor(srgbRed: 1.0, green: 1.0, blue: 1.0, alpha: alpha * 0.4),
                    CGColor(srgbRed: 1.0, green: 1.0, blue: 1.0, alpha: 0.0)
                ] as CFArray
                if let grad = CGGradient(colorsSpace: colorSpace, colors: cloudColors, locations: [0.0, 0.5, 1.0]) {
                    context.saveGState()
                    let rect = CGRect(x: cx - cloudW / 2, y: cy - cloudH / 2, width: cloudW, height: cloudH)
                    context.addEllipse(in: rect)
                    context.clip()
                    context.drawRadialGradient(
                        grad,
                        startCenter: CGPoint(x: cx, y: cy),
                        startRadius: 0,
                        endCenter: CGPoint(x: cx, y: cy),
                        endRadius: cloudW / 2,
                        options: []
                    )
                    context.restoreGState()
                }
            }

        case .fog, .haze:
            // 3 bands at maximum opacity 0.16
            for band in particles {
                let bandH = CGFloat(band.size * 1.4)
                let cy = CGFloat(band.y) * CGFloat(height)
                let bandColors = [
                    CGColor(srgbRed: 1.0, green: 1.0, blue: 1.0, alpha: 0.0),
                    CGColor(srgbRed: 1.0, green: 1.0, blue: 1.0, alpha: 0.16),
                    CGColor(srgbRed: 1.0, green: 1.0, blue: 1.0, alpha: 0.0)
                ] as CFArray
                if let grad = CGGradient(colorsSpace: colorSpace, colors: bandColors, locations: [0.0, 0.5, 1.0]) {
                    context.drawLinearGradient(
                        grad,
                        start: CGPoint(x: CGFloat(width) / 2.0, y: cy - bandH / 2),
                        end: CGPoint(x: CGFloat(width) / 2.0, y: cy + bandH / 2),
                        options: []
                    )
                }
            }

        case .rain, .thunderstorm:
            // Top cloud band at maximum opacity 0.18
            let topH = CGFloat(height) * 0.24
            let cloudColors = [
                CGColor(srgbRed: 0.0, green: 0.0, blue: 0.0, alpha: 0.18),
                CGColor(srgbRed: 0.0, green: 0.0, blue: 0.0, alpha: 0.12),
                CGColor(srgbRed: 0.0, green: 0.0, blue: 0.0, alpha: 0.0)
            ] as CFArray
            if let grad = CGGradient(colorsSpace: colorSpace, colors: cloudColors, locations: [0.0, 0.6, 1.0]) {
                context.drawLinearGradient(
                    grad,
                    start: CGPoint(x: CGFloat(width) / 2.0, y: 0),
                    end: CGPoint(x: CGFloat(width) / 2.0, y: topH),
                    options: []
                )
            }
            // 60 rain streaks at maximum opacity 0.58
            context.setStrokeColor(CGColor(srgbRed: 1.0, green: 1.0, blue: 1.0, alpha: 0.58))
            context.setLineWidth(1.1)
            for rain in particles {
                let rx = CGFloat(rain.x) * CGFloat(width)
                let ry = CGFloat(rain.y) * CGFloat(height)
                let dx = CGFloat(rain.length) * 0.20
                let dy = CGFloat(rain.length)
                context.move(to: CGPoint(x: rx, y: ry))
                context.addLine(to: CGPoint(x: rx + dx, y: ry + dy))
                context.strokePath()
            }

        case .snow:
            // 50 snow dots: max opacity 0.78, capped to 0.38 in text area
            for flake in particles {
                let fx = CGFloat(flake.x) * CGFloat(width)
                let fy = CGFloat(flake.y) * CGFloat(height)
                let inTextArea = fx <= CGFloat(width) / 3.0 && fy <= CGFloat(height) / 3.0
                let alpha: CGFloat
                if inTextArea && capOpacityInTextArea {
                    alpha = 0.38
                    opacityCapped = true
                } else {
                    alpha = 0.78
                }
                context.setFillColor(CGColor(srgbRed: 1.0, green: 1.0, blue: 1.0, alpha: alpha))
                let r = CGFloat(flake.size * 0.5)
                context.fillEllipse(in: CGRect(x: fx - r, y: fy - r, width: 2 * r, height: 2 * r))
            }
        }

        // 3. Scrim: black 0.0 at top to 0.15 at bottom
        let scrimColors = [
            CGColor(srgbRed: 0.0, green: 0.0, blue: 0.0, alpha: 0.0),
            CGColor(srgbRed: 0.0, green: 0.0, blue: 0.0, alpha: 0.15)
        ] as CFArray
        if let scrimGrad = CGGradient(colorsSpace: colorSpace, colors: scrimColors, locations: [0.0, 1.0]) {
            context.drawLinearGradient(
                scrimGrad,
                start: CGPoint(x: CGFloat(width) / 2.0, y: 0),
                end: CGPoint(x: CGFloat(width) / 2.0, y: CGFloat(height)),
                options: []
            )
        }

        // 4. Sample pixel luminance in temperature text area (top-left third)
        let sampleW = width / 3
        let sampleH = height / 3
        guard let pixelData = context.data else {
            fatalError("Context data unavailable")
        }

        let buffer = pixelData.bindMemory(to: UInt8.self, capacity: height * bytesPerRow)
        var sumLuminance: Double = 0.0
        var maxLuminance: Double = 0.0
        var pixelCount = 0

        for y in 0..<sampleH {
            let rowOffset = y * bytesPerRow
            for x in 0..<sampleW {
                let offset = rowOffset + x * 4
                let rByte = buffer[offset]
                let gByte = buffer[offset + 1]
                let bByte = buffer[offset + 2]
                let aByte = buffer[offset + 3]

                let alpha = Double(aByte) / 255.0
                guard alpha > 0 else { continue }
                let r = (Double(rByte) / 255.0) / alpha
                let g = (Double(gByte) / 255.0) / alpha
                let b = (Double(bByte) / 255.0) / alpha

                let l = WCAGHelper.relativeLuminance(r: min(1.0, max(0.0, r)), g: min(1.0, max(0.0, g)), b: min(1.0, max(0.0, b)))
                sumLuminance += l
                if l > maxLuminance {
                    maxLuminance = l
                }
                pixelCount += 1
            }
        }

        let avgLuminance = pixelCount > 0 ? sumLuminance / Double(pixelCount) : 0.0
        let contrast = (1.0 + 0.05) / (avgLuminance + 0.05)

        return CompositedSceneMeasurement(
            scene: scene,
            sampledLuminance: avgLuminance,
            contrastRatio: contrast,
            opacityCapped: opacityCapped
        )
    }
}

// MARK: - Sky Background Tests Suite

@Suite("Sky Background Tests")
struct SkyBackgroundTests {

    // MARK: - Condition Mapping

    @Test("SkyScene.from maps conditions accurately for day and night")
    func testSkySceneMapping() {
        // Clear / Sunny conditions
        #expect(SkyScene.from(condition: "Clear", isDaylight: true) == .clearDay)
        #expect(SkyScene.from(condition: "Clear", isDaylight: false) == .clearNight)
        #expect(SkyScene.from(condition: "Sunny", isDaylight: true) == .clearDay)
        #expect(SkyScene.from(condition: "Sunny", isDaylight: false) == .clearNight)
        #expect(SkyScene.from(condition: "Mostly Clear", isDaylight: true) == .clearDay)
        #expect(SkyScene.from(condition: "Hot", isDaylight: true) == .clearDay)
        #expect(SkyScene.from(condition: "", isDaylight: true) == .clearDay)
        #expect(SkyScene.from(condition: "", isDaylight: false) == .clearNight)
        #expect(SkyScene.from(condition: nil, isDaylight: true) == .clearDay)
        #expect(SkyScene.from(condition: nil, isDaylight: false) == .clearNight)

        // Partly cloudy
        #expect(SkyScene.from(condition: "Partly Cloudy", isDaylight: true) == .partlyCloudy(isDaylight: true))
        #expect(SkyScene.from(condition: "Partly Cloudy", isDaylight: false) == .partlyCloudy(isDaylight: false))
        #expect(SkyScene.from(condition: "Mostly Cloudy", isDaylight: true) == .partlyCloudy(isDaylight: true))
        #expect(SkyScene.from(condition: "Breezy", isDaylight: true) == .partlyCloudy(isDaylight: true))
        #expect(SkyScene.from(condition: "Windy", isDaylight: false) == .partlyCloudy(isDaylight: false))

        // Cloudy / Overcast
        #expect(SkyScene.from(condition: "Cloudy", isDaylight: true) == .cloudy)
        #expect(SkyScene.from(condition: "Cloudy", isDaylight: false) == .cloudy)
        #expect(SkyScene.from(condition: "Overcast", isDaylight: true) == .cloudy)

        // Fog / Mist
        #expect(SkyScene.from(condition: "Fog", isDaylight: true) == .fog)
        #expect(SkyScene.from(condition: "Foggy", isDaylight: false) == .fog)
        #expect(SkyScene.from(condition: "Mist", isDaylight: true) == .fog)

        // Haze / Smoke / Dust
        #expect(SkyScene.from(condition: "Haze", isDaylight: true) == .haze)
        #expect(SkyScene.from(condition: "Hazy", isDaylight: false) == .haze)
        #expect(SkyScene.from(condition: "Smoky", isDaylight: true) == .haze)
        #expect(SkyScene.from(condition: "Blowing Dust", isDaylight: true) == .haze)

        // Rain / Drizzle / Showers
        #expect(SkyScene.from(condition: "Rain", isDaylight: true) == .rain)
        #expect(SkyScene.from(condition: "Drizzle", isDaylight: false) == .rain)
        #expect(SkyScene.from(condition: "Heavy Rain", isDaylight: true) == .rain)
        #expect(SkyScene.from(condition: "Rain Showers", isDaylight: false) == .rain)

        // Thunderstorm / Storms
        #expect(SkyScene.from(condition: "Thunderstorm", isDaylight: true) == .thunderstorm)
        #expect(SkyScene.from(condition: "Severe Thunderstorm", isDaylight: false) == .thunderstorm)
        #expect(SkyScene.from(condition: "Isolated Thunderstorms", isDaylight: true) == .thunderstorm)
        #expect(SkyScene.from(condition: "Tropical Storm", isDaylight: true) == .thunderstorm)

        // Snow / Sleet / Blizzard
        #expect(SkyScene.from(condition: "Snow", isDaylight: true) == .snow)
        #expect(SkyScene.from(condition: "Blizzard", isDaylight: false) == .snow)
        #expect(SkyScene.from(condition: "Flurries", isDaylight: true) == .snow)
        #expect(SkyScene.from(condition: "Sleet", isDaylight: false) == .snow)
        #expect(SkyScene.from(condition: "Hail", isDaylight: true) == .snow)
        #expect(SkyScene.from(condition: "Wintry Mix", isDaylight: true) == .snow)
    }

    // MARK: - 1. Gradient Stops Match Hex Values Test

    @Test("Each scene's gradient stops match the exact spec hex values")
    func testGradientStopsMatchHex() {
        let expectedHexes: [(scene: SkyScene, top: String, bottom: String)] = [
            (.clearDay, "#1F4F78", "#3E7396"),
            (.clearNight, "#080F25", "#182641"),
            (.cloudy, "#3D5366", "#667784"),
            (.fog, "#405E61", "#647676"),
            (.rain, "#243748", "#465D70"),
            (.snow, "#40576D", "#637788"),
            (.partlyCloudy(isDaylight: true), "#3D5366", "#667784")
        ]

        for item in expectedHexes {
            #expect(item.scene.gradientHex.top == item.top, "Top hex mismatch for \(item.scene.displayName)")
            #expect(item.scene.gradientHex.bottom == item.bottom, "Bottom hex mismatch for \(item.scene.displayName)")

            let stops = item.scene.gradientStops
            let expectedTop = SkyScene.hexToRGB(item.top)
            let expectedBottom = SkyScene.hexToRGB(item.bottom)

            #expect(abs(stops.top.r - expectedTop.r) < 0.001)
            #expect(abs(stops.top.g - expectedTop.g) < 0.001)
            #expect(abs(stops.top.b - expectedTop.b) < 0.001)

            #expect(abs(stops.bottom.r - expectedBottom.r) < 0.001)
            #expect(abs(stops.bottom.g - expectedBottom.g) < 0.001)
            #expect(abs(stops.bottom.b - expectedBottom.b) < 0.001)
        }
    }

    // MARK: - 2. Opacity Ranges Match Spec Test

    @Test("Opacity ranges match the spec across multiple seeds")
    func testOpacityRangesMatchSpec() {
        for seed in [42, 100, 2024, 99999] as [UInt64] {
            // Clear night: 40 stars, twinkle opacity range 0.62 to 0.88
            let stars = SkyParticleGenerator.generate(for: .clearNight, seed: seed)
            for s in stars {
                #expect(s.opacity >= 0.62 && s.opacity <= 0.88, "Star opacity \(s.opacity) outside 0.62...0.88")
            }

            // Cloudy: 5 clouds, opacity range 0.10 to 0.18
            let clouds = SkyParticleGenerator.generate(for: .cloudy, seed: seed)
            for c in clouds {
                #expect(c.opacity >= 0.10 && c.opacity <= 0.18, "Cloud opacity \(c.opacity) outside 0.10...0.18")
            }

            // Fog: 3 bands, opacity range 0.10 to 0.16
            let fogBands = SkyParticleGenerator.generate(for: .fog, seed: seed)
            for f in fogBands {
                #expect(f.opacity >= 0.10 && f.opacity <= 0.16, "Fog band opacity \(f.opacity) outside 0.10...0.16")
            }

            // Rain: 60 streaks, opacity range 0.34 to 0.58
            let rainStreaks = SkyParticleGenerator.generate(for: .rain, seed: seed)
            for r in rainStreaks {
                #expect(r.opacity >= 0.34 && r.opacity <= 0.58, "Rain streak opacity \(r.opacity) outside 0.34...0.58")
            }

            // Snow: 50 dots, opacity range 0.38 to 0.78
            let snowDots = SkyParticleGenerator.generate(for: .snow, seed: seed)
            for sn in snowDots {
                #expect(sn.opacity >= 0.38 && sn.opacity <= 0.78, "Snow dot opacity \(sn.opacity) outside 0.38...0.78")
            }

            // Clear day: 2 rays, opacity 0.10
            let rays = SkyParticleGenerator.generate(for: .clearDay, seed: seed)
            for ray in rays {
                #expect(abs(ray.opacity - 0.10) < 0.001, "Ray opacity \(ray.opacity) must be 0.10")
            }
        }
    }

    // MARK: - 3. Particle Counts Test

    @Test("Particle counts match the exact spec (clear night 40, cloudy 5, fog 3, rain 60, snow 50)")
    func testParticleCountsMatchSpec() {
        #expect(SkyParticleGenerator.generate(for: .clearNight).count == 40, "Clear night must have 40 stars")
        #expect(SkyParticleGenerator.generate(for: .cloudy).count == 5, "Cloudy must have 5 clouds")
        #expect(SkyParticleGenerator.generate(for: .fog).count == 3, "Fog must have 3 bands")
        #expect(SkyParticleGenerator.generate(for: .rain).count == 60, "Rain must have 60 streaks")
        #expect(SkyParticleGenerator.generate(for: .snow).count == 50, "Snow must have 50 dots")
        #expect(SkyParticleGenerator.generate(for: .clearDay).count == 2, "Clear day must have 2 rays")
        #expect(SkyParticleGenerator.generate(for: .partlyCloudy(isDaylight: true)).count == 3, "Partly cloudy must have 3 clouds")
    }

    // MARK: - 4. Composited Contrast Gate Test for All Scenes

    @Test("Composited contrast test for all six scenes meets 4.5:1 body and 3:1 large text")
    func testCompositedContrastGate() {
        let scenesToTest: [SkyScene] = [
            .clearDay,
            .clearNight,
            .cloudy,
            .fog,
            .rain,
            .snow
        ]

        var summaryOutputs: [String] = []

        for scene in scenesToTest {
            let measurement = CompositedSceneRenderer.renderAndMeasure(
                scene: scene,
                size: CGSize(width: 390, height: 844),
                capOpacityInTextArea: true
            )

            // White text meets WCAG 4.5:1 (body) and 3:1 (large)
            #expect(
                measurement.contrastRatio >= 4.5,
                "\(scene.displayName) contrast \(String(format: "%.2f", measurement.contrastRatio)):1 failed 4.5:1 body text requirement"
            )
            #expect(
                measurement.contrastRatio >= 3.0,
                "\(scene.displayName) contrast \(String(format: "%.2f", measurement.contrastRatio)):1 failed 3.0:1 large text requirement"
            )

            let capNote = measurement.opacityCapped ? " (opacity capped in text area)" : ""
            summaryOutputs.append(
                "\(scene.displayName): \(String(format: "%.2f", measurement.contrastRatio)):1\(capNote)"
            )
        }

        let logger = Logger(subsystem: "com.vedanshi.upthereapp", category: "SkyBackgroundTests")
        logger.info("=== COMPOSITED CONTRAST RATIO REPORT ===")
        for line in summaryOutputs {
            logger.info("\(line, privacy: .public)")
        }
    }
}
