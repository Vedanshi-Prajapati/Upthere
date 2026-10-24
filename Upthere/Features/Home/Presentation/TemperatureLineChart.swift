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

    private let plotTopPadding: CGFloat = 20
    private let plotBottomPadding: CGFloat = 8

    private func xPos(_ index: Int, in width: CGFloat) -> CGFloat {
        guard hourly.count > 1 else { return width / 2 }
        return CGFloat(index) / CGFloat(hourly.count - 1) * width
    }

    private func yPos(_ temp: Double, in height: CGFloat) -> CGFloat {
        let availableHeight = height - plotTopPadding - plotBottomPadding
        let fraction = CGFloat((temp - minT) / tempRange)
        return (height - plotBottomPadding) - max(0, min(1, fraction)) * availableHeight
    }

    @Environment(\.weatherFormatter) private var weatherFormatter
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedIndex: Int?
    @State private var isDragging = false

    var body: some View {
        VStack(spacing: 8) {
            if hourly.isEmpty {
                Text("Hourly forecast unavailable")
                    .font(.subheadline)
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
                                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.3)) {
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Temperature forecast chart")
        .accessibilityValue(accessibilitySummary)
    }

    private var accessibilitySummary: String {
        guard let first = hourly.first else { return "Hourly forecast unavailable" }
        let nowTemp = weatherFormatter.temp(first.temperature)
        let peak = hourly.max(by: { $0.temperature < $1.temperature }) ?? first
        let trough = hourly.min(by: { $0.temperature < $1.temperature }) ?? first

        if peak.temperature > first.temperature + 1.0 {
            let peakTemp = weatherFormatter.temp(peak.temperature)
            return "Temperature rises from \(nowTemp) now to \(peakTemp) at \(peak.time)"
        } else if trough.temperature < first.temperature - 1.0 {
            let troughTemp = weatherFormatter.temp(trough.temperature)
            return "Temperature falls from \(nowTemp) now to \(troughTemp) at \(trough.time)"
        } else {
            return "Temperature steady around \(nowTemp) now, high of \(weatherFormatter.temp(high)), low of \(weatherFormatter.temp(low))"
        }
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
                    .font(.caption.weight(.medium))
                    .foregroundStyle(AppTheme.textSecondary)
                Text(weatherFormatter.temp(item.temperature))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.textPrimary)
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
            // High reference guide line - distinct dash pattern [6, 4] with WCAG AA compliant contrast
            Path { p in
                p.move(to: CGPoint(x: 0, y: highY))
                p.addLine(to: CGPoint(x: w, y: highY))
            }
            .stroke(AppTheme.chartGrid,
                    style: StrokeStyle(lineWidth: 1.2, dash: [6, 4]))

            // Low reference guide line - distinct fine dash [2, 3] with WCAG AA compliant contrast
            Path { p in
                p.move(to: CGPoint(x: 0, y: lowY))
                p.addLine(to: CGPoint(x: w, y: lowY))
            }
            .stroke(AppTheme.chartGridLow,
                    style: StrokeStyle(lineWidth: 1.2, dash: [2, 3]))
        }
    }

    private func smoothPath(in width: CGFloat, height: CGFloat, isClosed: Bool = false) -> Path {
        var path = Path()
        guard !hourly.isEmpty else { return path }
        let points: [CGPoint] = hourly.indices.map { i in
            CGPoint(x: xPos(i, in: width), y: yPos(hourly[i].temperature, in: height))
        }
        guard points.count > 1 else {
            path.move(to: points[0])
            return path
        }

        let n = points.count
        var deltas: [CGFloat] = []
        for i in 0..<(n - 1) {
            let dx = points[i + 1].x - points[i].x
            let dy = points[i + 1].y - points[i].y
            deltas.append(dx == 0 ? 0 : dy / dx)
        }

        var m: [CGFloat] = Array(repeating: 0, count: n)
        m[0] = deltas[0]
        m[n - 1] = deltas[n - 2]

        for i in 1..<(n - 1) {
            if deltas[i - 1] * deltas[i] <= 0 {
                m[i] = 0
            } else {
                m[i] = (deltas[i - 1] + deltas[i]) / 2.0
            }
        }

        for i in 0..<(n - 1) {
            if deltas[i] == 0 {
                m[i] = 0
                m[i + 1] = 0
            } else {
                let alpha = m[i] / deltas[i]
                let beta = m[i + 1] / deltas[i]
                let dist = alpha * alpha + beta * beta
                if dist > 9.0 {
                    let tau = 3.0 / sqrt(dist)
                    m[i] = tau * alpha * deltas[i]
                    m[i + 1] = tau * beta * deltas[i]
                }
            }
        }

        if isClosed {
            path.move(to: CGPoint(x: points[0].x, y: height))
            path.addLine(to: points[0])
        } else {
            path.move(to: points[0])
        }

        for i in 0..<(n - 1) {
            let p0 = points[i]
            let p1 = points[i + 1]
            let dx = p1.x - p0.x
            let c1 = CGPoint(x: p0.x + dx / 3.0, y: p0.y + m[i] * dx / 3.0)
            let c2 = CGPoint(x: p1.x - dx / 3.0, y: p1.y - m[i + 1] * dx / 3.0)
            path.addCurve(to: p1, control1: c1, control2: c2)
        }

        if isClosed {
            path.addLine(to: CGPoint(x: points[n - 1].x, y: height))
            path.closeSubpath()
        }

        return path
    }

    private func areaFill(w: CGFloat, h: CGFloat) -> some View {
        smoothPath(in: w, height: h, isClosed: true)
            .fill(LinearGradient(
                colors: [Color.white.opacity(0.18), Color.white.opacity(0.02)],
                startPoint: .top,
                endPoint: .bottom
            ))
    }

    private func temperatureLine(w: CGFloat, h: CGFloat) -> some View {
        smoothPath(in: w, height: h, isClosed: false)
            .stroke(AppTheme.chartLine, lineWidth: 2.75)
    }

    private func peakDotAndLabel(w: CGFloat, h: CGFloat) -> some View {
        Group {
            if let peakIdx = hourly.indices.max(by: { hourly[$0].temperature < hourly[$1].temperature }) {
                let px = xPos(peakIdx, in: w)
                let py = yPos(hourly[peakIdx].temperature, in: h)
                let highX = min(max(px, 30), w - 30)
                let nowX: CGFloat = 34

                let isColliding = peakIdx == 0 || abs(highX - nowX) < 48

                Circle()
                    .fill(AppTheme.chartSelectedPoint)
                    .frame(width: 7, height: 7)
                    .position(x: px, y: py)

                if !isColliding {
                    Text("H \(weatherFormatter.temp(high))")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                        .position(x: highX, y: 8)
                }
            }
        }
    }

    private func nowDotAndLabel(w: CGFloat, h: CGFloat) -> some View {
        Group {
            if let first = hourly.first {
                let py = yPos(first.temperature, in: h)
                let px = xPos(0, in: w)

                Circle()
                    .fill(AppTheme.chartSelectedPoint)
                    .frame(width: 7, height: 7)
                    .position(x: px, y: py)

                Text("Now \(weatherFormatter.temp(first.temperature))")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .position(x: 34, y: 8)
            }
        }
    }

    private var xAxisLabels: some View {
        HStack {
            ForEach(sampledLabels, id: \.self) { label in
                Text(label)
                    .font(.caption)
                    .foregroundStyle(AppTheme.chartAxisLabel)
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
