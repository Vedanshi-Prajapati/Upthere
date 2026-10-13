import SwiftUI

// MARK: - TemperatureLineChart

struct TemperatureLineChart: View {
    let hourly: [HourlyWeather]
    let high: Double
    let low: Double

    private var temps: [Double] { hourly.map(\.temperature) }
    private var minT: Double { (temps.min() ?? low) - 1 }
    private var maxT: Double { (temps.max() ?? high) + 1 }
    private var tempRange: Double { max(1.0, maxT - minT) }

    private func xPos(_ index: Int, in width: CGFloat) -> CGFloat {
        guard hourly.count > 1 else { return width / 2 }
        return CGFloat(index) / CGFloat(hourly.count - 1) * width
    }

    private func yPos(_ temp: Double, in height: CGFloat) -> CGFloat {
        let fraction = CGFloat((temp - minT) / tempRange)
        return height - max(0, min(1, fraction)) * height
    }

    @State private var selectedIndex: Int?
    @State private var isDragging = false

    var body: some View {
        VStack(spacing: 8) {
            if hourly.isEmpty {
                Text("Hourly forecast unavailable")
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(height: 95)
            } else {
                GeometryReader { geo in
                    let w = geo.size.width
                    let h = geo.size.height

                    ZStack(alignment: .topLeading) {
                        dashedHighLine(w: w, h: h)
                        areaFill(w: w, h: h)
                        temperatureLine(w: w, h: h)

                        if !isDragging {
                            peakDotAndLabel(w: w, h: h)
                            nowDotAndLabel(w: w, h: h)
                        } else if let selectedIndex, hourly.indices.contains(selectedIndex) {
                            scrubberOverlay(index: selectedIndex, w: w, h: h)
                        }
                    }
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                guard hourly.count > 1 else { return }
                                let rawFraction = value.location.x / w
                                let clamped = max(0, min(1, rawFraction))
                                let newIndex = min(hourly.count - 1, max(0, Int(round(clamped * CGFloat(hourly.count - 1)))))

                                if selectedIndex != newIndex {
                                    selectedIndex = newIndex
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                }
                                isDragging = true
                            }
                            .onEnded { _ in
                                withAnimation(.easeOut(duration: 0.3)) {
                                    isDragging = false
                                    selectedIndex = nil
                                }
                            }
                    )
                }
                .frame(height: 95)

                xAxisLabels
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Temperature timeline chart showing \(hourly.count) hours")
    }

    private func scrubberOverlay(index: Int, w: CGFloat, h: CGFloat) -> some View {
        let px = xPos(index, in: w)
        let item = hourly[index]
        let py = yPos(item.temperature, in: h)

        return ZStack {
            // Vertical cursor line
            Path { p in
                p.move(to: CGPoint(x: px, y: 0))
                p.addLine(to: CGPoint(x: px, y: h))
            }
            .stroke(Color.white.opacity(0.45), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))

            // Outer glow circle
            Circle()
                .fill(Color.white.opacity(0.25))
                .frame(width: 16, height: 16)
                .position(x: px, y: py)

            // Inner solid dot
            Circle()
                .fill(Color.white)
                .frame(width: 8, height: 8)
                .position(x: px, y: py)

            // Floating value badge
            HStack(spacing: 4) {
                Text(item.time)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.8))
                Text(WeatherFormatter.shared.temp(item.temperature))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(Color(red: 18/255, green: 42/255, blue: 82/255).opacity(0.92))
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.25), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.25), radius: 6, y: 2)
            )
            .position(
                x: min(max(px, 45), w - 45),
                y: max(14, py - 22)
            )
        }
    }

    private func dashedHighLine(w: CGFloat, h: CGFloat) -> some View {
        let highY = yPos(high, in: h)
        let lowY = yPos(low, in: h)
        return Group {
            // High reference guide line
            Path { p in
                p.move(to: CGPoint(x: 0, y: highY))
                p.addLine(to: CGPoint(x: w, y: highY))
            }
            .stroke(Color.white.opacity(0.22),
                    style: StrokeStyle(lineWidth: 1, dash: [4, 4]))

            // Low reference guide line
            Path { p in
                p.move(to: CGPoint(x: 0, y: lowY))
                p.addLine(to: CGPoint(x: w, y: lowY))
            }
            .stroke(Color.white.opacity(0.12),
                    style: StrokeStyle(lineWidth: 1, dash: [3, 4]))
        }
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
        .stroke(Color.white, lineWidth: 2.75)
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
                Text("H \(WeatherFormatter.shared.temp(high))")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .position(x: min(max(px, 24), w - 24), y: max(10, py - 14))
            }
        }
    }

    private func nowDotAndLabel(w: CGFloat, h: CGFloat) -> some View {
        Group {
            if let first = hourly.first {
                let py = yPos(first.temperature, in: h)
                let peakIdx = hourly.indices.max(by: { hourly[$0].temperature < hourly[$1].temperature }) ?? 0
                let px = xPos(peakIdx, in: w)
                // If peak is within 65px horizontally of Now, drop Now label below the line to avoid collision
                let isCollidingWithPeak = abs(px - 34) < 65
                let nowLabelY = isCollidingWithPeak ? min(h - 10, py + 15) : max(10, py - 14)

                Circle()
                    .fill(Color.white)
                    .frame(width: 7, height: 7)
                    .position(x: xPos(0, in: w), y: py)
                Text("Now \(WeatherFormatter.shared.temp(first.temperature))")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .position(x: 34, y: nowLabelY)
            }
        }
    }

    private var xAxisLabels: some View {
        HStack {
            ForEach(sampledLabels, id: \.self) { label in
                Text(label)
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var sampledLabels: [String] {
        guard !hourly.isEmpty else { return [] }
        if hourly.count <= 5 {
            return hourly.map(\.time)
        }
        let count = hourly.count
        let indices = [0, count / 4, count / 2, 3 * count / 4, count - 1]
        return indices.map { hourly[$0].time }
    }
}
