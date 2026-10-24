import SwiftUI
import os

// MARK: - 1. Realistic Sky Canvas (Natural color temperature & atmospheric perspective)

struct RealisticSkyCanvas: View {
    let type: WeatherVisualType
    var reduceMotion: Bool = false

    @Environment(\.weatherClockTime) private var clockTime
    @Environment(\.isWeatherAnimationPaused) private var isPaused

    var body: some View {
        let lightShift: Double = (reduceMotion || isPaused) ? 0.0 : 0.03 * sin(clockTime * (2.0 * .pi / 24.0))

        skyBody(lightShift: lightShift)
            .animation(reduceMotion ? nil : .easeInOut(duration: 1.4), value: type)
            .allowsHitTesting(false)
    }

    private func skyBody(lightShift: Double) -> some View {
        let signpostID = WeatherSignpost.signposter.makeSignpostID()
        let state = WeatherSignpost.signposter.beginInterval("RealisticSkyCanvasDraw", id: signpostID)
        defer { WeatherSignpost.signposter.endInterval("RealisticSkyCanvasDraw", state) }

        return GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height

            ZStack {
                // True atmospheric sky gradient: zenith (top) -> horizon (bottom)
                LinearGradient(
                    stops: skyStops(for: type, lightShift: lightShift),
                    startPoint: .top,
                    endPoint: .bottom
                )

                // Distant sunlight bleed from outside the upper-trailing frame (Sunny / Clear)
                if type == .sunny {
                    RadialGradient(
                        colors: [
                            Color(red: 1.0, green: 0.96, blue: 0.88).opacity(0.22 + lightShift),
                            Color(red: 0.85, green: 0.92, blue: 1.0).opacity(0.08),
                            Color.clear
                        ],
                        center: UnitPoint(x: 1.15, y: -0.10), // Outside the frame
                        startRadius: 80,
                        endRadius: max(w, h) * 0.95
                    )
                }

                // Soft ambient horizon haze (for Cloudy, Rain, Snow)
                if type == .cloudy || type == .rainy || type == .snowy {
                    LinearGradient(
                        colors: [
                            Color.clear,
                            horizonHazeColor(for: type).opacity(0.18)
                        ],
                        startPoint: .center,
                        endPoint: .bottom
                    )
                }
            }
        }
    }

    private func skyStops(for type: WeatherVisualType, lightShift: Double) -> [Gradient.Stop] {
        switch type {
        case .sunny:
            // Darkened lower gradient stops — ensures secondary text reaches ≥ 4.5:1 on sunny skies
            return [
                .init(color: Color(red: 0.05, green: 0.20, blue: 0.50).opacity(1.0 + lightShift), location: 0.0),
                .init(color: Color(red: 0.08, green: 0.28, blue: 0.58), location: 0.40),
                .init(color: Color(red: 0.12, green: 0.34, blue: 0.62), location: 0.72),
                .init(color: Color(red: 0.16, green: 0.38, blue: 0.66), location: 1.0)
            ]
        case .partlyCloudy:
            // Darkened lower gradient stops — contrast-safe for secondary text
            return [
                .init(color: Color(red: 0.06, green: 0.18, blue: 0.44), location: 0.0),
                .init(color: Color(red: 0.10, green: 0.24, blue: 0.50), location: 0.45),
                .init(color: Color(red: 0.14, green: 0.30, blue: 0.56), location: 0.75),
                .init(color: Color(red: 0.18, green: 0.36, blue: 0.60), location: 1.0)
            ]
        case .cloudy:
            // Soft diffuse overcast: muted atmospheric slate-gray/blue-gray palette
            return [
                .init(color: Color(red: 0.14, green: 0.18, blue: 0.25), location: 0.0),
                .init(color: Color(red: 0.20, green: 0.26, blue: 0.33), location: 0.45),
                .init(color: Color(red: 0.28, green: 0.34, blue: 0.41), location: 0.80),
                .init(color: Color(red: 0.35, green: 0.40, blue: 0.47), location: 1.0)
            ]
        case .rainy:
            // Naturally overcast blue-gray sky with atmospheric depth
            return [
                .init(color: Color(red: 0.10, green: 0.18, blue: 0.30), location: 0.0),
                .init(color: Color(red: 0.16, green: 0.25, blue: 0.37), location: 0.45),
                .init(color: Color(red: 0.24, green: 0.32, blue: 0.44), location: 0.80),
                .init(color: Color(red: 0.30, green: 0.38, blue: 0.48), location: 1.0)
            ]
        case .thunderstorm:
            // Deep, dense storm canopy: heavy slate-indigo with dark cloud weight
            return [
                .init(color: Color(red: 0.06, green: 0.08, blue: 0.16), location: 0.0),
                .init(color: Color(red: 0.10, green: 0.13, blue: 0.22), location: 0.45),
                .init(color: Color(red: 0.15, green: 0.18, blue: 0.28), location: 0.80),
                .init(color: Color(red: 0.20, green: 0.22, blue: 0.32), location: 1.0)
            ]
        case .snowy:
            // Muted, cold sky with soft icy haze
            return [
                .init(color: Color(red: 0.18, green: 0.27, blue: 0.42), location: 0.0),
                .init(color: Color(red: 0.28, green: 0.38, blue: 0.52), location: 0.45),
                .init(color: Color(red: 0.42, green: 0.52, blue: 0.65), location: 0.82),
                .init(color: Color(red: 0.55, green: 0.64, blue: 0.74), location: 1.0)
            ]
        case .night:
            // Deep navy sky with natural darkening gradient
            return [
                .init(color: Color(red: 0.03, green: 0.04, blue: 0.11), location: 0.0),
                .init(color: Color(red: 0.05, green: 0.08, blue: 0.18), location: 0.50),
                .init(color: Color(red: 0.08, green: 0.12, blue: 0.24), location: 0.85),
                .init(color: Color(red: 0.10, green: 0.15, blue: 0.28), location: 1.0)
            ]
        case .defaultTheme:
            return [
                .init(color: Color(red: 0.08, green: 0.22, blue: 0.52), location: 0.0),
                .init(color: Color(red: 0.12, green: 0.30, blue: 0.60), location: 0.50),
                .init(color: Color(red: 0.18, green: 0.38, blue: 0.66), location: 1.0)
            ]
        }
    }

    private func horizonHazeColor(for type: WeatherVisualType) -> Color {
        switch type {
        case .cloudy: return Color(red: 0.50, green: 0.54, blue: 0.60)
        case .rainy: return Color(red: 0.35, green: 0.42, blue: 0.50)
        case .snowy: return Color(red: 0.65, green: 0.72, blue: 0.80)
        default: return Color.white.opacity(0.10)
        }
    }
}
