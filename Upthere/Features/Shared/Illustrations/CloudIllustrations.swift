import SwiftUI

// MARK: - 3. Partly Cloudy Day Graphic

struct PartlyCloudyDayIllustration: View {
    let size: CGFloat
    let time: TimeInterval
    let animated: Bool

    var body: some View {
        let sunPulse = animated ? sin(time * 2.0) * 0.04 : 0.0
        let cloudFloat = animated ? sin(time * 1.6) * (size * 0.015) : 0.0

        ZStack {
            // Sun in upper right
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(red: 1.0, green: 0.85, blue: 0.3).opacity(0.55),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: size * 0.06,
                            endRadius: size * 0.28
                        )
                    )
                    .frame(width: size * 0.58, height: size * 0.58)

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 1.0, green: 0.93, blue: 0.45),
                                Color(red: 1.0, green: 0.65, blue: 0.15),
                                Color(red: 0.98, green: 0.42, blue: 0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: size * 0.44, height: size * 0.44)
                    .shadow(color: Color(red: 1.0, green: 0.6, blue: 0.15).opacity(0.6), radius: size * 0.03)
            }
            .scaleEffect(1.0 + sunPulse)
            .offset(x: size * 0.18, y: -size * 0.16)

            // Back atmospheric shadow cloud
            VolumetricCloudShape()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.72, green: 0.80, blue: 0.92),
                            Color(red: 0.55, green: 0.65, blue: 0.80)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: size * 0.74, height: size * 0.48)
                .offset(x: -size * 0.12, y: size * 0.10)
                .opacity(0.65)

            // Front luminous fluffy cloud
            ZStack {
                VolumetricCloudShape()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white,
                                Color(red: 0.92, green: 0.95, blue: 0.99),
                                Color(red: 0.80, green: 0.87, blue: 0.96)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: size * 0.82, height: size * 0.52)
                    .shadow(color: Color.black.opacity(0.20), radius: size * 0.02, x: 0, y: size * 0.02)

                VolumetricCloudShape()
                    .stroke(
                        LinearGradient(
                            colors: [Color.white, Color.white.opacity(0.35), Color.clear],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: max(1.2, size * 0.025)
                    )
                    .frame(width: size * 0.82, height: size * 0.52)
            }
            .offset(x: -size * 0.06, y: size * 0.14 + cloudFloat)
        }
    }
}

// MARK: - 4. Partly Cloudy Night Graphic

struct PartlyCloudyNightIllustration: View {
    let size: CGFloat
    let time: TimeInterval
    let animated: Bool

    var body: some View {
        let moonFloat = animated ? sin(time * 1.5) * (size * 0.015) : 0.0
        let cloudFloat = animated ? cos(time * 1.8) * (size * 0.015) : 0.0
        let starTwinkle = animated ? (sin(time * 3.0) + 1.0) * 0.5 : 0.8

        ZStack {
            // Sparkle star
            SparkleStarShape()
                .fill(Color.white)
                .frame(width: size * 0.15, height: size * 0.15)
                .position(x: size * 0.86, y: size * 0.18)
                .scaleEffect(0.65 + starTwinkle * 0.5)
                .opacity(0.40 + starTwinkle * 0.60)

            // Crescent Moon in background
            CrescentMoonShape()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 1.0, green: 0.98, blue: 0.90),
                            Color(red: 0.88, green: 0.92, blue: 0.98),
                            Color(red: 0.72, green: 0.82, blue: 0.96)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size * 0.48, height: size * 0.48)
                .shadow(color: Color(red: 0.65, green: 0.78, blue: 1.0).opacity(0.55), radius: size * 0.02)
                .offset(x: size * 0.16, y: -size * 0.16 + moonFloat)

            // Front nocturnal cloud
            ZStack {
                VolumetricCloudShape()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.45, green: 0.52, blue: 0.68),
                                Color(red: 0.28, green: 0.34, blue: 0.48),
                                Color(red: 0.18, green: 0.22, blue: 0.35)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: size * 0.82, height: size * 0.52)
                    .shadow(color: Color.black.opacity(0.35), radius: size * 0.02, x: 0, y: size * 0.02)

                VolumetricCloudShape()
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color(red: 0.88, green: 0.94, blue: 1.0).opacity(0.8),
                                Color.white.opacity(0.15),
                                Color.clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: max(1.2, size * 0.025)
                    )
                    .frame(width: size * 0.82, height: size * 0.52)
            }
            .offset(x: -size * 0.05, y: size * 0.14 + cloudFloat)
        }
    }
}

// MARK: - 5. Cloudy Graphic (Volumetric Layered Clouds)

struct CloudyIllustration: View {
    let size: CGFloat
    let time: TimeInterval
    let animated: Bool

    var body: some View {
        let drift = animated ? sin(time * 1.5) * (size * 0.015) : 0.0

        ZStack {
            // Back cloud layer
            VolumetricCloudShape()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.70, green: 0.76, blue: 0.85),
                            Color(red: 0.52, green: 0.58, blue: 0.68)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: size * 0.76, height: size * 0.48)
                .offset(x: size * 0.08, y: -size * 0.10 - drift)

            // Front cloud layer
            ZStack {
                VolumetricCloudShape()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white,
                                Color(red: 0.90, green: 0.93, blue: 0.97),
                                Color(red: 0.74, green: 0.80, blue: 0.88)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: size * 0.86, height: size * 0.54)
                    .shadow(color: Color.black.opacity(0.24), radius: size * 0.02, x: 0, y: size * 0.04)

                VolumetricCloudShape()
                    .stroke(
                        LinearGradient(
                            colors: [Color.white, Color.white.opacity(0.35), Color.clear],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: max(1.2, size * 0.025)
                    )
                    .frame(width: size * 0.86, height: size * 0.54)
            }
            .offset(x: -size * 0.05, y: size * 0.08 + drift)
        }
    }
}
