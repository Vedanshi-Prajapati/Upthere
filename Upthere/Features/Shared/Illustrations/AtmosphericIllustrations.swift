import SwiftUI

// MARK: - 9. Windy Graphic (Breezy Cloud & Wind Gust Ribbons)

struct WindyIllustration: View {
    let size: CGFloat
    let time: TimeInterval
    let animated: Bool

    var body: some View {
        let gust = animated ? sin(time * 2.2) * (size * 0.05) : 0.0

        ZStack {
            VolumetricCloudShape()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white,
                            Color(red: 0.90, green: 0.94, blue: 0.98),
                            Color(red: 0.78, green: 0.85, blue: 0.94)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: size * 0.76, height: size * 0.48)
                .offset(x: -size * 0.08, y: -size * 0.08)

            VStack(spacing: size * 0.08) {
                WindStreamlineShape()
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color(red: 0.55, green: 0.82, blue: 1.0).opacity(0.20),
                                Color(red: 0.75, green: 0.92, blue: 1.0),
                                Color.white
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: max(1.5, size * 0.035), lineCap: .round)
                    )
                    .frame(width: size * 0.65, height: size * 0.08)
                    .offset(x: gust)

                WindStreamlineShape()
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color(red: 0.55, green: 0.82, blue: 1.0).opacity(0.20),
                                Color(red: 0.75, green: 0.92, blue: 1.0),
                                Color.white
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: max(1.5, size * 0.035), lineCap: .round)
                    )
                    .frame(width: size * 0.52, height: size * 0.08)
                    .offset(x: -gust * 0.8 + size * 0.05)
            }
            .offset(y: size * 0.22)
        }
    }
}

// MARK: - 10. Foggy Graphic (Ethereal Mist Bars)

struct FoggyIllustration: View {
    let size: CGFloat
    let time: TimeInterval
    let animated: Bool

    var body: some View {
        let drift = animated ? sin(time * 1.4) * (size * 0.04) : 0.0

        VStack(spacing: size * 0.08) {
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.20),
                            Color.white.opacity(0.85),
                            Color.white.opacity(0.20)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: size * 0.72, height: max(3, size * 0.07))
                .offset(x: drift)

            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.30),
                            Color.white.opacity(0.95),
                            Color.white.opacity(0.30)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: size * 0.86, height: max(3.5, size * 0.08))
                .offset(x: -drift * 1.2)

            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.15),
                            Color.white.opacity(0.75),
                            Color.white.opacity(0.15)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: size * 0.65, height: max(3, size * 0.07))
                .offset(x: drift * 0.8)
        }
    }
}
