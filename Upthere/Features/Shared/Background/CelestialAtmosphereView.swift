import SwiftUI

// MARK: - 2. Sunny / Clear Atmosphere
// Faint wispy cirrus streaks with turbulence, sun glow from outside the frame.

struct SunnyAtmosphere: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate

            Canvas { context, size in
                // --- Wispy cirrus bands: each built from many thin overlapping streaks ---
                let bandCount = 4
                let driftSpeed: Double = 1.2

                for i in 0..<bandCount {
                    let baseSeed = Double(i) * 67.3
                    let bandY = size.height * (0.08 + CGFloat(i) * 0.12)
                    let cycleW = size.width * 2.2

                    // Each band is 5-7 thin overlapping wisps
                    let wispCount = 5 + Int(seededRandom(baseSeed + 10) * 3)

                    for w in 0..<wispCount {
                        let ws = Double(w)
                        let r1 = seededRandom(baseSeed + ws * 11.3)
                        let r2 = seededRandom2(baseSeed, ws * 9.7)
                        let r3 = seededRandom(baseSeed + ws * 23.1 + 100)

                        let wispWidth = size.width * (0.3 + r1 * 0.5)
                        let wispHeight: CGFloat = 12 + CGFloat(r2) * 35
                        let xShift = (r3 - 0.5) * size.width * 0.6

                        let xPos = (CGFloat(t * (driftSpeed + ws * 0.15)) + CGFloat(baseSeed * 30) + xShift)
                            .truncatingRemainder(dividingBy: cycleW) - wispWidth * 0.3
                        let yPos = bandY + CGFloat(r2 - 0.5) * 30

                        context.opacity = 0.025 + r3 * 0.025

                        let rect = CGRect(x: xPos, y: yPos, width: wispWidth, height: wispHeight)
                        context.fill(
                            Path(ellipseIn: rect),
                            with: .radialGradient(
                                Gradient(colors: [
                                    Color.white.opacity(0.50),
                                    Color.white.opacity(0.15),
                                    Color.clear
                                ]),
                                center: CGPoint(x: rect.midX, y: rect.midY),
                                startRadius: 0,
                                endRadius: wispWidth * 0.45
                            )
                        )
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - 7. Clear Night Atmosphere
// Deep sky with sparse stars of varying color temperature and gentle scintillation,
// plus a faint Milky Way band.

struct ClearNightAtmosphere: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 15.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate

            Canvas { context, size in
                // --- Faint Milky Way band ---
                context.opacity = 0.04
                let bandWidth = size.width * 0.35
                let bandRect = CGRect(
                    x: size.width * 0.25,
                    y: -size.height * 0.1,
                    width: bandWidth,
                    height: size.height * 0.8
                )
                context.fill(
                    Path(ellipseIn: bandRect),
                    with: .radialGradient(
                        Gradient(colors: [
                            Color(red: 0.70, green: 0.75, blue: 0.90).opacity(0.5),
                            Color(red: 0.50, green: 0.55, blue: 0.75).opacity(0.2),
                            Color.clear
                        ]),
                        center: CGPoint(x: bandRect.midX, y: bandRect.midY),
                        startRadius: 10,
                        endRadius: bandWidth * 0.5
                    )
                )

                // --- Stars with color temperature variation ---
                let starCount = 30

                for i in 0..<starCount {
                    let seed = Double(i) * 29.8
                    let xPos = seededRandom(seed) * size.width
                    let yPos = seededRandom(seed + 50) * size.height * 0.75 // Upper sky bias

                    // Star color: warm white, cool blue-white, or pale gold
                    let colorSeed = seededRandom(seed + 100)
                    let starColor: Color
                    if colorSeed < 0.4 {
                        starColor = Color(red: 1.0, green: 0.98, blue: 0.94) // Warm white
                    } else if colorSeed < 0.75 {
                        starColor = Color(red: 0.88, green: 0.92, blue: 1.0) // Cool blue-white
                    } else {
                        starColor = Color(red: 1.0, green: 0.95, blue: 0.80) // Pale gold
                    }

                    // Scintillation with varying speeds
                    let twinkleSpeed = 0.6 + seededRandom(seed + 200) * 0.8
                    let twinklePhase = seededRandom(seed + 300) * .pi * 2
                    let twinkle = 0.15 + 0.40 * (0.5 + 0.5 * sin(t * twinkleSpeed + twinklePhase))

                    let isBright = seededRandom(seed + 400) > 0.8
                    let r: CGFloat = isBright ? (1.1 + CGFloat(seededRandom(seed + 500)) * 0.5) : (0.6 + CGFloat(seededRandom(seed + 500)) * 0.3)

                    // Soft glow around bright stars
                    if isBright {
                        context.opacity = twinkle * 0.25
                        let glowR = r * 4.0
                        context.fill(
                            Path(ellipseIn: CGRect(x: xPos - glowR, y: yPos - glowR, width: glowR * 2, height: glowR * 2)),
                            with: .radialGradient(
                                Gradient(colors: [starColor.opacity(0.4), Color.clear]),
                                center: CGPoint(x: xPos, y: yPos),
                                startRadius: 0,
                                endRadius: glowR
                            )
                        )
                    }

                    context.opacity = twinkle
                    context.fill(
                        Path(ellipseIn: CGRect(x: xPos - r, y: yPos - r, width: r * 2, height: r * 2)),
                        with: .color(starColor)
                    )
                }
            }
        }
        .allowsHitTesting(false)
    }
}
