import SwiftUI

// MARK: - 1. Clear Day Graphic (Radiant Sun with Corona Rays & Solar Glow)

struct ClearDayIllustration: View {
    let size: CGFloat
    let time: TimeInterval
    let animated: Bool

    var body: some View {
        let pulse = animated ? sin(time * 1.8) * 0.04 : 0.0
        let rayAngle = animated ? (time * 12.0).truncatingRemainder(dividingBy: 360.0) : 0.0

        ZStack {
            // Ambient solar bloom
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 1.0, green: 0.82, blue: 0.25).opacity(0.50),
                            Color(red: 1.0, green: 0.55, blue: 0.12).opacity(0.18),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: size * 0.08,
                        endRadius: size * 0.48
                    )
                )
                .frame(width: size, height: size)
                .scaleEffect(1.0 + pulse)

            // Radiant corona rays
            SunRaysView(size: size * 0.88)
                .rotationEffect(.degrees(rayAngle))

            // Core sun sphere with rich multi-stop gradient
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 1.0, green: 0.94, blue: 0.50), // Pure luminous gold
                                Color(red: 1.0, green: 0.68, blue: 0.15), // Warm solar amber
                                Color(red: 0.96, green: 0.40, blue: 0.08)  // Sunset rim
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: size * 0.54, height: size * 0.54)
                    .shadow(color: Color(red: 1.0, green: 0.6, blue: 0.1).opacity(0.65), radius: size * 0.03, x: 0, y: size * 0.04)

                // 3D Glass specular gloss arc
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.85),
                                Color.white.opacity(0.20),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: max(1.5, size * 0.035)
                    )
                    .frame(width: size * 0.46, height: size * 0.46)
                    .offset(x: -size * 0.015, y: -size * 0.015)
            }
            .scaleEffect(1.0 + pulse * 0.6)
        }
    }
}

// MARK: - 2. Clear Night Graphic (Luminous Crescent Moon & Twinkling 4-Point Stars)

struct ClearNightIllustration: View {
    let size: CGFloat
    let time: TimeInterval
    let animated: Bool

    var body: some View {
        let moonFloat = animated ? sin(time * 1.5) * (size * 0.02) : 0.0
        let s1Pulse = animated ? (sin(time * 2.8) + 1.0) * 0.5 : 0.8
        let s2Pulse = animated ? (sin(time * 3.4 + 1.2) + 1.0) * 0.5 : 0.7
        let s3Pulse = animated ? (sin(time * 2.2 + 2.5) + 1.0) * 0.5 : 0.9

        ZStack {
            // Celestial moonlight aura
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.65, green: 0.80, blue: 1.0).opacity(0.38),
                            Color(red: 0.45, green: 0.55, blue: 0.95).opacity(0.12),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: size * 0.12,
                        endRadius: size * 0.48
                    )
                )
                .frame(width: size, height: size)

            // Sparkle Star 1 (Top right)
            SparkleStarShape()
                .fill(
                    LinearGradient(
                        colors: [Color.white, Color(red: 0.82, green: 0.92, blue: 1.0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: size * 0.22, height: size * 0.22)
                .shadow(color: Color(red: 0.7, green: 0.85, blue: 1.0).opacity(0.85), radius: size * 0.02)
                .position(x: size * 0.82, y: size * 0.24)
                .scaleEffect(0.65 + s1Pulse * 0.5)
                .opacity(0.40 + s1Pulse * 0.60)

            // Sparkle Star 2 (Far right middle)
            SparkleStarShape()
                .fill(Color.white)
                .frame(width: size * 0.15, height: size * 0.15)
                .shadow(color: Color.white.opacity(0.75), radius: size * 0.015)
                .position(x: size * 0.90, y: size * 0.56)
                .scaleEffect(0.60 + s2Pulse * 0.5)
                .opacity(0.35 + s2Pulse * 0.65)

            // Sparkle Star 3 (Lower center subtle twinkle)
            SparkleStarShape()
                .fill(Color(red: 0.88, green: 0.94, blue: 1.0))
                .frame(width: size * 0.12, height: size * 0.12)
                .position(x: size * 0.60, y: size * 0.84)
                .scaleEffect(0.55 + s3Pulse * 0.5)
                .opacity(0.30 + s3Pulse * 0.70)

            // Crescent Moon Body
            ZStack {
                CrescentMoonShape()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 1.0, green: 0.98, blue: 0.90),  // Pale moonlight ivory
                                Color(red: 0.92, green: 0.94, blue: 0.98),  // Soft silver cream
                                Color(red: 0.75, green: 0.84, blue: 0.98)   // Celestial blue-silver rim
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: size * 0.64, height: size * 0.64)
                    .shadow(color: Color(red: 0.65, green: 0.80, blue: 1.0).opacity(0.55), radius: size * 0.03, x: -size * 0.01, y: size * 0.02)

                // Outer crescent specular edge
                CrescentMoonShape()
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.95),
                                Color.white.opacity(0.20)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: max(1.2, size * 0.025)
                    )
                    .frame(width: size * 0.64, height: size * 0.64)
            }
            .offset(x: -size * 0.05, y: moonFloat)
        }
    }
}
