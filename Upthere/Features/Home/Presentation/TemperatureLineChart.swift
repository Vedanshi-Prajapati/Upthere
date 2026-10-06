import SwiftUI

// MARK: - TemperatureLineChart

struct TemperatureLineChart: View {
    let hourly: [HourlyWeather]
    let high: Double
    let low: Double

    private var temps: [Double] { hourly.map(\.temperature) }
    private var minT: Double { (temps.min() ?? low) - 1 }
    private var maxT: Double { (temps.max() ?? high) + 1 }
    private var tempRange: Double { maxT - minT }

    private func xPos(_ index: Int, in width: CGFloat) -> CGFloat {
        guard hourly.count > 1 else { return 0 }
        return CGFloat(index) / CGFloat(hourly.count - 1) * width
    }

    private func yPos(_ temp: Double, in height: CGFloat) -> CGFloat {
        height - CGFloat((temp - minT) / tempRange) * height
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack(alignment: .topLeading) {
                dashedHighLine(w: w, h: h)
                areaFill(w: w, h: h)
                temperatureLine(w: w, h: h)
                peakDotAndLabel(w: w, h: h)
                nowDotAndLabel(w: w, h: h)
            }
            .overlay(alignment: .bottom) {
                xAxisLabels
                    .offset(y: 18)
            }
        }
    }

    private func dashedHighLine(w: CGFloat, h: CGFloat) -> some View {
        let highY = yPos(high, in: h)
        return Path { p in
            p.move(to: CGPoint(x: 0, y: highY))
            p.addLine(to: CGPoint(x: w, y: highY))
        }
        .stroke(Color.white.opacity(0.30),
                style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
    }

    private func areaFill(w: CGFloat, h: CGFloat) -> some View {
        Path { p in
            guard !hourly.isEmpty else { return }
            p.move(to: CGPoint(x: xPos(0, in: w), y: h))
            for (i, item) in hourly.enumerated() {
                p.addLine(to: CGPoint(x: xPos(i, in: w), y: yPos(item.temperature, in: h)))
            }
            p.addLine(to: CGPoint(x: xPos(hourly.count - 1, in: w), y: h))
            p.closeSubpath()
        }
        .fill(LinearGradient(
            colors: [Color.white.opacity(0.18), Color.white.opacity(0.02)],
            startPoint: .top,
            endPoint: .bottom
        ))
    }

    private func temperatureLine(w: CGFloat, h: CGFloat) -> some View {
        Path { p in
            guard !hourly.isEmpty else { return }
            p.move(to: CGPoint(x: xPos(0, in: w), y: yPos(hourly[0].temperature, in: h)))
            for i in 1..<hourly.count {
                let prevX = xPos(i - 1, in: w)
                let currX = xPos(i, in: w)
                let midX = (prevX + currX) / 2
                p.addCurve(
                    to: CGPoint(x: currX, y: yPos(hourly[i].temperature, in: h)),
                    control1: CGPoint(x: midX, y: yPos(hourly[i - 1].temperature, in: h)),
                    control2: CGPoint(x: midX, y: yPos(hourly[i].temperature, in: h))
                )
            }
        }
        .stroke(Color.white, lineWidth: 2)
    }

    private func peakDotAndLabel(w: CGFloat, h: CGFloat) -> some View {
        Group {
            if let peakIdx = hourly.indices.max(by: { hourly[$0].temperature < hourly[$1].temperature }) {
                let px = xPos(peakIdx, in: w)
                let py = yPos(hourly[peakIdx].temperature, in: h)
                Circle()
                    .fill(Color.white)
                    .frame(width: 7, height: 7)
                    .position(x: px, y: py)
                Text("H \(Int(high))°")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .position(x: min(max(px, 22), w - 22), y: py - 14)
            }
        }
    }

    private func nowDotAndLabel(w: CGFloat, h: CGFloat) -> some View {
        Group {
            if let first = hourly.first {
                let py = yPos(first.temperature, in: h)
                Circle()
                    .fill(Color.white)
                    .frame(width: 7, height: 7)
                    .position(x: xPos(0, in: w), y: py)
                Text("Now \(Int(first.temperature))°")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .position(x: 34, y: py - 14)
            }
        }
    }

    private var xAxisLabels: some View {
        HStack {
            ForEach(["Now", "9a", "12p", "3p", "8p"], id: \.self) { label in
                Text(label)
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }
}
