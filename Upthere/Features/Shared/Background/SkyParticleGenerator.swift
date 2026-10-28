import Foundation

// MARK: - Seeded RNG (Linear Congruential Generator)

public struct SeededRNG: RandomNumberGenerator {
    private var state: UInt64

    public init(seed: UInt64 = 42) {
        self.state = seed != 0 ? seed : 0x4d595df4d0f33173
    }

    public mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }

    public mutating func nextDouble(in range: ClosedRange<Double> = 0.0...1.0) -> Double {
        let value = Double(next() % 1_000_000) / 999_999.0
        return range.lowerBound + value * (range.upperBound - range.lowerBound)
    }
}

// MARK: - Particle Model

public struct SkyParticle: Equatable, Sendable {
    public let id: Int
    public let x: Double        // Normalized 0.0...1.0
    public let y: Double        // Normalized 0.0...1.0
    public let size: Double     // Dimensions in points (width/radius)
    public let speedX: Double   // Horizontal velocity
    public let speedY: Double   // Vertical velocity
    public let opacity: Double  // Base opacity
    public let phase: Double    // Periodic phase offset (radians)
    public let length: Double   // For line strokes (rain, rays)
}

// MARK: - Generator

public enum SkyParticleGenerator {
    public static func generate(for scene: SkyScene, seed: UInt64 = 42) -> [SkyParticle] {
        var rng = SeededRNG(seed: seed)
        var particles: [SkyParticle] = []

        switch scene {
        case .clearNight:
            // 40 stars, twinkle opacity range 0.62 to 0.88
            let count = scene.expectedParticleCount // 40
            for i in 0..<count {
                particles.append(
                    SkyParticle(
                        id: i,
                        x: rng.nextDouble(in: 0.02...0.98),
                        y: rng.nextDouble(in: 0.03...0.85),
                        size: rng.nextDouble(in: 1.0...2.4),
                        speedX: rng.nextDouble(in: -0.5...0.5),
                        speedY: rng.nextDouble(in: -0.3...0.3),
                        opacity: rng.nextDouble(in: 0.62...0.88),
                        phase: rng.nextDouble(in: 0.0...(2 * .pi)),
                        length: 0.0
                    )
                )
            }

        case .clearDay:
            // 2 rays, opacity 0.10
            let count = scene.expectedParticleCount // 2
            for i in 0..<count {
                particles.append(
                    SkyParticle(
                        id: i,
                        x: 0.85,
                        y: 0.08,
                        size: rng.nextDouble(in: 40...70),
                        speedX: rng.nextDouble(in: 0.2...0.4),
                        speedY: 0.0,
                        opacity: 0.10, // Exact 0.10
                        phase: Double(i) * (.pi / 2.0),
                        length: rng.nextDouble(in: 340...480)
                    )
                )
            }

        case .partlyCloudy:
            // 3 clouds, opacity range 0.10 to 0.18, in 3 depth layers
            let count = scene.expectedParticleCount // 3
            for i in 0..<count {
                let depthLayer = i % 3
                let (speedRange, sizeRange): (ClosedRange<Double>, ClosedRange<Double>) = {
                    switch depthLayer {
                    case 0: return (6.0...10.0, 180...240)
                    case 1: return (10.0...16.0, 240...300)
                    default: return (16.0...22.0, 300...380)
                    }
                }()
                particles.append(
                    SkyParticle(
                        id: i,
                        x: rng.nextDouble(in: 0.0...1.0),
                        y: 0.06 + Double(i) * 0.18 + rng.nextDouble(in: -0.03...0.03),
                        size: rng.nextDouble(in: sizeRange),
                        speedX: rng.nextDouble(in: speedRange),
                        speedY: 0.0,
                        opacity: rng.nextDouble(in: 0.10...0.18),
                        phase: rng.nextDouble(in: 0.0...(2 * .pi)),
                        length: 0.0
                    )
                )
            }

        case .cloudy:
            // 5 clouds, opacity range 0.10 to 0.18, in 3 depth layers
            let count = scene.expectedParticleCount // 5
            for i in 0..<count {
                let depthLayer = i % 3
                let (speedRange, sizeRange): (ClosedRange<Double>, ClosedRange<Double>) = {
                    switch depthLayer {
                    case 0: return (6.0...10.0, 180...240)
                    case 1: return (10.0...16.0, 240...300)
                    default: return (16.0...22.0, 300...380)
                    }
                }()
                particles.append(
                    SkyParticle(
                        id: i,
                        x: rng.nextDouble(in: 0.0...1.0),
                        y: 0.05 + Double(i) * 0.14 + rng.nextDouble(in: -0.03...0.03),
                        size: rng.nextDouble(in: sizeRange),
                        speedX: rng.nextDouble(in: speedRange),
                        speedY: 0.0,
                        opacity: rng.nextDouble(in: 0.10...0.18),
                        phase: rng.nextDouble(in: 0.0...(2 * .pi)),
                        length: 0.0
                    )
                )
            }

        case .fog, .haze:
            // 3 bands, opacity range 0.10 to 0.16
            let count = scene.expectedParticleCount // 3
            for i in 0..<count {
                particles.append(
                    SkyParticle(
                        id: i,
                        x: 0.5,
                        y: 0.20 + Double(i) * 0.26,
                        size: rng.nextDouble(in: 140...240),
                        speedX: rng.nextDouble(in: 5.0...12.0),
                        speedY: 0.0,
                        opacity: rng.nextDouble(in: 0.10...0.16),
                        phase: Double(i) * 1.5,
                        length: 0.0
                    )
                )
            }

        case .rain, .thunderstorm:
            // 60 streaks, opacity range 0.34 to 0.58
            let count = scene.expectedParticleCount // 60
            for i in 0..<count {
                particles.append(
                    SkyParticle(
                        id: i,
                        x: rng.nextDouble(in: 0.0...1.0),
                        y: rng.nextDouble(in: 0.0...1.0),
                        size: rng.nextDouble(in: 0.8...1.4),
                        speedX: 0.0,
                        speedY: rng.nextDouble(in: 340...620),
                        opacity: rng.nextDouble(in: 0.34...0.58),
                        phase: rng.nextDouble(in: 0.0...(2 * .pi)),
                        length: rng.nextDouble(in: 16...34)
                    )
                )
            }

        case .snow:
            // 50 dots, opacity range 0.38 to 0.78
            let count = scene.expectedParticleCount // 50
            for i in 0..<count {
                particles.append(
                    SkyParticle(
                        id: i,
                        x: rng.nextDouble(in: 0.0...1.0),
                        y: rng.nextDouble(in: 0.0...1.0),
                        size: rng.nextDouble(in: 2.0...4.5),
                        speedX: rng.nextDouble(in: 0.5...1.5),
                        speedY: rng.nextDouble(in: 30...70),
                        opacity: rng.nextDouble(in: 0.38...0.78),
                        phase: rng.nextDouble(in: 0.0...(2 * .pi)),
                        length: 0.0
                    )
                )
            }
        }

        return particles
    }
}
