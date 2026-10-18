import SwiftUI

// MARK: - Vector Shapes & Primitives

// 1. Sun Corona Rays
struct SunRaysView: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            ForEach(0..<8) { i in
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 1.0, green: 0.88, blue: 0.35),
                                Color(red: 1.0, green: 0.60, blue: 0.12).opacity(0.65)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: max(2, size * 0.06), height: size * 0.20)
                    .offset(y: -size * 0.40)
                    .rotationEffect(.degrees(Double(i) * 45))
            }
        }
    }
}

// 2. Crescent Moon Shape
nonisolated struct CrescentMoonShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height

        path.move(to: CGPoint(x: w * 0.72, y: h * 0.08))
        path.addCurve(
            to: CGPoint(x: w * 0.72, y: h * 0.92),
            control1: CGPoint(x: -w * 0.08, y: h * 0.20),
            control2: CGPoint(x: -w * 0.08, y: h * 0.80)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.72, y: h * 0.08),
            control1: CGPoint(x: w * 0.25, y: h * 0.75),
            control2: CGPoint(x: w * 0.25, y: h * 0.25)
        )
        path.closeSubpath()
        return path
    }
}

// 3. Sparkle Star Shape
nonisolated struct SparkleStarShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let midX = rect.midX
        let midY = rect.midY
        let w = rect.width
        let h = rect.height

        path.move(to: CGPoint(x: midX, y: 0))
        path.addQuadCurve(to: CGPoint(x: w, y: midY), control: CGPoint(x: midX + w * 0.12, y: midY - h * 0.12))
        path.addQuadCurve(to: CGPoint(x: midX, y: h), control: CGPoint(x: midX + w * 0.12, y: midY + h * 0.12))
        path.addQuadCurve(to: CGPoint(x: 0, y: midY), control: CGPoint(x: midX - w * 0.12, y: midY + h * 0.12))
        path.addQuadCurve(to: CGPoint(x: midX, y: 0), control: CGPoint(x: midX - w * 0.12, y: midY - h * 0.12))
        path.closeSubpath()
        return path
    }
}

// 4. Volumetric Cloud Compound Shape (Continuous organic silhouette without internal overlapping strokes)
nonisolated struct VolumetricCloudShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height

        // Start at flat base left
        path.move(to: CGPoint(x: w * 0.18, y: h * 0.82))
        path.addLine(to: CGPoint(x: w * 0.82, y: h * 0.82))

        // Right puff
        path.addCurve(
            to: CGPoint(x: w * 0.90, y: h * 0.58),
            control1: CGPoint(x: w * 0.88, y: h * 0.82),
            control2: CGPoint(x: w * 0.94, y: h * 0.70)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.72, y: h * 0.36),
            control1: CGPoint(x: w * 0.90, y: h * 0.44),
            control2: CGPoint(x: w * 0.82, y: h * 0.36)
        )

        // Center upper puff
        path.addCurve(
            to: CGPoint(x: w * 0.38, y: h * 0.30),
            control1: CGPoint(x: w * 0.65, y: h * 0.14),
            control2: CGPoint(x: w * 0.46, y: h * 0.14)
        )

        // Left puff
        path.addCurve(
            to: CGPoint(x: w * 0.12, y: h * 0.58),
            control1: CGPoint(x: w * 0.24, y: h * 0.30),
            control2: CGPoint(x: w * 0.10, y: h * 0.42)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.18, y: h * 0.82),
            control1: CGPoint(x: w * 0.08, y: h * 0.72),
            control2: CGPoint(x: w * 0.12, y: h * 0.82)
        )

        path.closeSubpath()
        return path
    }
}

// 5. Rain Drop Streak
struct RainDropStreak: View {
    let length: CGFloat
    let width: CGFloat

    var body: some View {
        Capsule()
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.50, green: 0.85, blue: 1.0),
                        Color(red: 0.15, green: 0.55, blue: 0.95)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: width, height: length)
            .rotationEffect(.degrees(16))
    }
}

// 6. Lightning Bolt Shape
nonisolated struct LightningBoltShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height

        path.move(to: CGPoint(x: w * 0.62, y: 0))
        path.addLine(to: CGPoint(x: w * 0.22, y: h * 0.50))
        path.addLine(to: CGPoint(x: w * 0.48, y: h * 0.50))
        path.addLine(to: CGPoint(x: w * 0.32, y: h))
        path.addLine(to: CGPoint(x: w * 0.82, y: h * 0.42))
        path.addLine(to: CGPoint(x: w * 0.54, y: h * 0.42))
        path.closeSubpath()
        return path
    }
}

// 7. Snowflake Shape
nonisolated struct SnowflakeShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let midX = rect.midX
        let midY = rect.midY
        let radius = min(rect.width, rect.height) / 2

        for i in 0..<6 {
            let angle = Double(i) * (.pi / 3)
            let endX = midX + CGFloat(cos(angle)) * radius
            let endY = midY + CGFloat(sin(angle)) * radius

            path.move(to: CGPoint(x: midX, y: midY))
            path.addLine(to: CGPoint(x: endX, y: endY))

            let b1X = midX + CGFloat(cos(angle)) * (radius * 0.65)
            let b1Y = midY + CGFloat(sin(angle)) * (radius * 0.65)
            let branchAngle1 = angle + .pi / 4
            let branchAngle2 = angle - .pi / 4
            let bLen = radius * 0.28

            path.move(to: CGPoint(x: b1X, y: b1Y))
            path.addLine(to: CGPoint(x: b1X + CGFloat(cos(branchAngle1)) * bLen, y: b1Y + CGFloat(sin(branchAngle1)) * bLen))

            path.move(to: CGPoint(x: b1X, y: b1Y))
            path.addLine(to: CGPoint(x: b1X + CGFloat(cos(branchAngle2)) * bLen, y: b1Y + CGFloat(sin(branchAngle2)) * bLen))
        }
        return path
    }
}

// 8. Wind Streamline Ribbon
nonisolated struct WindStreamlineShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height

        path.move(to: CGPoint(x: 0, y: h * 0.5))
        path.addCurve(
            to: CGPoint(x: w * 0.8, y: h * 0.3),
            control1: CGPoint(x: w * 0.3, y: h * 0.9),
            control2: CGPoint(x: w * 0.6, y: -h * 0.2)
        )
        path.addQuadCurve(
            to: CGPoint(x: w, y: h * 0.8),
            control: CGPoint(x: w * 0.95, y: h * 0.5)
        )
        return path
    }
}
