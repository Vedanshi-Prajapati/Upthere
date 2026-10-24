import SwiftUI

// MARK: - 6. Rainy Graphic (Volumetric Cloud & Cascading Animated Rain Drops)

struct RainyIllustration: View {
    let isHeavy: Bool
    let size: CGFloat
    let time: TimeInterval
    let animated: Bool

    var body: some View {
        let cloudBob = animated ? sin(time * 1.6) * (size * 0.015) : 0.0
        let travel = size * 0.22

        // Continuous falling rain math (60-120fps continuous looping waterfall)
        let drop1Prog = animated ? (time * 1.6).truncatingRemainder(dividingBy: 1.0) : 0.3
        let drop2Prog = animated ? (time * 1.6 + 0.33).truncatingRemainder(dividingBy: 1.0) : 0.7
        let drop3Prog = animated ? (time * 1.6 + 0.66).truncatingRemainder(dividingBy: 1.0) : 0.5
        let drop4Prog = animated ? (time * 1.6 + 0.45).truncatingRemainder(dividingBy: 1.0) : 0.8

        ZStack {
            // Cascading angled raindrops
            ZStack {
                // Drop 1 (left)
                RainDropStreak(length: size * (isHeavy ? 0.24 : 0.18), width: size * 0.045)
                    .offset(x: -size * 0.22, y: size * 0.22 + CGFloat(drop1Prog) * travel)
                    .opacity(rainOpacity(progress: drop1Prog))

                // Drop 2 (center-left)
                RainDropStreak(length: size * (isHeavy ? 0.26 : 0.20), width: size * 0.048)
                    .offset(x: -size * 0.07, y: size * 0.20 + CGFloat(drop2Prog) * travel)
                    .opacity(rainOpacity(progress: drop2Prog))

                // Drop 3 (center-right)
                RainDropStreak(length: size * (isHeavy ? 0.24 : 0.18), width: size * 0.045)
                    .offset(x: size * 0.08, y: size * 0.22 + CGFloat(drop3Prog) * travel)
                    .opacity(rainOpacity(progress: drop3Prog))

                if isHeavy {
                    // Drop 4 (far right)
                    RainDropStreak(length: size * 0.24, width: size * 0.045)
                        .offset(x: size * 0.22, y: size * 0.21 + CGFloat(drop4Prog) * travel)
                        .opacity(rainOpacity(progress: drop4Prog))
                }
            }

            // Dark rain cloud body
            ZStack {
                VolumetricCloudShape()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.58, green: 0.65, blue: 0.76),
                                Color(red: 0.38, green: 0.45, blue: 0.58),
                                Color(red: 0.25, green: 0.30, blue: 0.42)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: size * 0.84, height: size * 0.52)
                    .shadow(color: Color(red: 0.1, green: 0.2, blue: 0.35).opacity(0.38), radius: size * 0.02, x: 0, y: size * 0.04)

                VolumetricCloudShape()
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.65),
                                Color.white.opacity(0.18),
                                Color.clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: max(1.2, size * 0.025)
                    )
                    .frame(width: size * 0.84, height: size * 0.52)
            }
            .offset(y: -size * 0.06 + cloudBob)
        }
    }

    private func rainOpacity(progress: Double) -> Double {
        if !animated { return 0.90 }
        if progress < 0.20 { return progress / 0.20 }
        if progress > 0.80 { return (1.0 - progress) / 0.20 }
        return 0.95
    }
}

// MARK: - 7. Thunderstorm Graphic (Moody Cloud & Glowing Electric Lightning)

struct ThunderstormIllustration: View {
    let size: CGFloat
    let time: TimeInterval
    let animated: Bool

    var body: some View {
        let flashPulse = animated ? (sin(time * 3.5) + 1.0) * 0.5 : 0.8
        let rainProg = animated ? (time * 1.8).truncatingRemainder(dividingBy: 1.0) : 0.5

        ZStack {
            // Ambient electric bloom
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.6, green: 0.7, blue: 1.0).opacity(0.10 + flashPulse * 0.35),
                            Color(red: 0.8, green: 0.6, blue: 1.0).opacity(flashPulse * 0.18),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: size * 0.1,
                        endRadius: size * 0.45
                    )
                )
                .frame(width: size, height: size)

            // Lightning Bolt emerging under cloud
            ZStack {
                LightningBoltShape()
                    .fill(Color(red: 1.0, green: 0.85, blue: 0.2))
                    .frame(width: size * 0.32, height: size * 0.48)
                    .blur(radius: size * 0.06)
                    .opacity(0.40 + flashPulse * 0.60)

                LightningBoltShape()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white,
                                Color(red: 1.0, green: 0.95, blue: 0.5),
                                Color(red: 1.0, green: 0.78, blue: 0.1)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: size * 0.28, height: size * 0.44)
                    .shadow(color: Color(red: 1.0, green: 0.85, blue: 0.2), radius: size * 0.02)
            }
            .offset(x: size * 0.06, y: size * 0.22)
            .scaleEffect(0.95 + flashPulse * 0.10)

            // Falling rain streaks
            HStack(spacing: size * 0.28) {
                RainDropStreak(length: size * 0.22, width: size * 0.04)
                    .offset(y: size * 0.22 + CGFloat(rainProg) * size * 0.18)
                RainDropStreak(length: size * 0.22, width: size * 0.04)
                    .offset(y: size * 0.22 + CGFloat(rainProg) * size * 0.18)
            }
            .opacity(0.70)

            // Dark thundercloud
            ZStack {
                VolumetricCloudShape()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.45, green: 0.42, blue: 0.58),
                                Color(red: 0.28, green: 0.26, blue: 0.42),
                                Color(red: 0.16, green: 0.15, blue: 0.26)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: size * 0.86, height: size * 0.54)
                    .shadow(color: Color.black.opacity(0.45), radius: size * 0.025, x: 0, y: size * 0.04)

                VolumetricCloudShape()
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color(red: 0.85, green: 0.80, blue: 1.0).opacity(0.65),
                                Color.white.opacity(0.15),
                                Color.clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: max(1.2, size * 0.025)
                    )
                    .frame(width: size * 0.86, height: size * 0.54)
            }
            .offset(y: -size * 0.08)
        }
    }
}

// MARK: - 8. Snowy Graphic (Frosted Cloud & Drifting Crystalline Snowflakes)

struct SnowyIllustration: View {
    let size: CGFloat
    let time: TimeInterval
    let animated: Bool

    var body: some View {
        let rot = animated ? (time * 45.0).truncatingRemainder(dividingBy: 360.0) : 0.0
        let sway = animated ? sin(time * 2.0) * (size * 0.03) : 0.0

        ZStack {
            // Drifting snowflakes
            ZStack {
                SnowflakeShape()
                    .fill(Color.white)
                    .frame(width: size * 0.16, height: size * 0.16)
                    .shadow(color: Color(red: 0.7, green: 0.85, blue: 1.0).opacity(0.8), radius: size * 0.02)
                    .rotationEffect(.degrees(rot))
                    .offset(x: -size * 0.22 + sway, y: size * 0.24)

                SnowflakeShape()
                    .fill(Color(red: 0.88, green: 0.95, blue: 1.0))
                    .frame(width: size * 0.18, height: size * 0.18)
                    .shadow(color: Color(red: 0.7, green: 0.85, blue: 1.0).opacity(0.8), radius: size * 0.02)
                    .rotationEffect(.degrees(-rot * 0.8))
                    .offset(x: 0 - sway * 0.8, y: size * 0.28)

                SnowflakeShape()
                    .fill(Color.white)
                    .frame(width: size * 0.14, height: size * 0.14)
                    .rotationEffect(.degrees(rot * 1.2))
                    .offset(x: size * 0.22 + sway, y: size * 0.23)
            }

            // Frosted winter cloud
            ZStack {
                VolumetricCloudShape()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white,
                                Color(red: 0.92, green: 0.96, blue: 1.0),
                                Color(red: 0.75, green: 0.85, blue: 0.96)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: size * 0.84, height: size * 0.52)
                    .shadow(color: Color(red: 0.4, green: 0.6, blue: 0.8).opacity(0.25), radius: size * 0.02, x: 0, y: size * 0.04)

                VolumetricCloudShape()
                    .stroke(
                        LinearGradient(
                            colors: [Color.white, Color(red: 0.8, green: 0.9, blue: 1.0).opacity(0.55), Color.clear],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: max(1.2, size * 0.025)
                    )
                    .frame(width: size * 0.84, height: size * 0.52)
            }
            .offset(y: -size * 0.08)
        }
    }
}
