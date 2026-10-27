import Testing
import SwiftUI
@testable import Upthere

@Suite("Sky Background Tests")
struct SkyBackgroundTests {

    // MARK: - 1. SkyScene.from Mapping Tests

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

    // MARK: - 2. Particle Generator Determinism & Counts

    @Test("Particle generator produces identical output for same seed and exact counts per scene")
    func testParticleGeneratorCountsAndDeterminism() {
        let allScenes: [SkyScene] = [
            .clearNight,
            .clearDay,
            .partlyCloudy(isDaylight: true),
            .partlyCloudy(isDaylight: false),
            .cloudy,
            .fog,
            .haze,
            .rain,
            .thunderstorm,
            .snow
        ]

        for scene in allScenes {
            let particles1 = SkyParticleGenerator.generate(for: scene, seed: 12345)
            let particles2 = SkyParticleGenerator.generate(for: scene, seed: 12345)
            let particlesOtherSeed = SkyParticleGenerator.generate(for: scene, seed: 99999)

            // Determinism: Same seed -> exact same output
            #expect(particles1 == particles2, "Particles must be identical for identical seed for \(scene.displayName)")

            // Different seed -> different output
            #expect(particles1 != particlesOtherSeed, "Different seed must yield different output for \(scene.displayName)")

            // Particle counts as specified:
            #expect(particles1.count == scene.expectedParticleCount, "Count mismatch for \(scene.displayName): got \(particles1.count), expected \(scene.expectedParticleCount)")
        }

        // Verify specific per-scene counts explicitly:
        #expect(SkyParticleGenerator.generate(for: .clearNight).count == 40, "clearNight must have 40 stars")
        #expect(SkyParticleGenerator.generate(for: .clearDay).count == 3, "clearDay must have 3 light rays")
        #expect(SkyParticleGenerator.generate(for: .partlyCloudy(isDaylight: true)).count == 4, "partlyCloudy must have 4 clouds")
        #expect(SkyParticleGenerator.generate(for: .cloudy).count == 6, "cloudy must have 6 clouds")
        #expect(SkyParticleGenerator.generate(for: .fog).count == 3, "fog must have 3 bands")
        #expect(SkyParticleGenerator.generate(for: .haze).count == 3, "haze must have 3 bands")
        #expect(SkyParticleGenerator.generate(for: .rain).count == 60, "rain must have 60 diagonal lines")
        #expect(SkyParticleGenerator.generate(for: .thunderstorm).count == 60, "thunderstorm must have 60 diagonal lines")
        #expect(SkyParticleGenerator.generate(for: .snow).count == 50, "snow must have 50 dots")
    }

    // MARK: - 3. Contrast Test: Lightest and Darkest Stops with Card

    @Test("White text over each scene (gradient + scrim + card) meets 4.5:1 body and 3:1 large text")
    func testContrastOverScenesWithScrim() {
        let whiteFg = (r: 1.0, g: 1.0, b: 1.0, a: 1.0)
        let scrimBottomAlpha = 0.15 // Phase 4: Max 15% black at bottom, 0% at top
        let scrimTopAlpha = 0.0

        for scene in SkyScene.allCases {
            let (topStop, bottomStop) = scene.gradientStops

            // Top stop (at scrimTopAlpha = 0.0) with dark glass card
            let topEffective = WCAGHelper.applyScrim(bg: topStop, alpha: scrimTopAlpha)
            let topWithCard = WCAGHelper.composite(fg: (r: 0.08, g: 0.16, b: 0.32, a: 0.65), bg: topEffective)
            let topRatio = WCAGHelper.contrastRatio(fg: whiteFg, bg: topWithCard)

            // Bottom stop (at scrimBottomAlpha = 0.15) with dark glass card
            let bottomEffective = WCAGHelper.applyScrim(bg: bottomStop, alpha: scrimBottomAlpha)
            let bottomWithCard = WCAGHelper.composite(fg: (r: 0.08, g: 0.16, b: 0.32, a: 0.65), bg: bottomEffective)
            let bottomRatio = WCAGHelper.contrastRatio(fg: whiteFg, bg: bottomWithCard)

            // Body text requires 4.5:1
            #expect(
                topRatio >= 4.5,
                "White body text on top stop with card of [\(scene.displayName)] must meet 4.5:1. Got \(String(format: "%.2f", topRatio)):1"
            )
            #expect(
                bottomRatio >= 4.5,
                "White body text on bottom stop with card of [\(scene.displayName)] must meet 4.5:1. Got \(String(format: "%.2f", bottomRatio)):1"
            )

            // Large text requires 3.0:1
            #expect(
                topRatio >= 3.0,
                "White large text on top stop with card of [\(scene.displayName)] must meet 3.0:1. Got \(String(format: "%.2f", topRatio)):1"
            )
            #expect(
                bottomRatio >= 3.0,
                "White large text on bottom stop with card of [\(scene.displayName)] must meet 3.0:1. Got \(String(format: "%.2f", bottomRatio)):1"
            )
        }
    }
}
