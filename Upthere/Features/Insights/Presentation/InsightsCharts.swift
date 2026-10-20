import SwiftUI

// MARK: - Mini Charts

extension InsightsView {
    struct PrecipitationBarChart: View {
        let hourly: [HourlyWeather]

        private var chartSummary: String {
            guard !hourly.isEmpty else { return "No precipitation data" }
            let peak = hourly.max(by: { $0.precipitationProbability < $1.precipitationProbability })
            let pct = Int(round((peak?.precipitationProbability ?? 0) * 100))
            return "Precipitation probability timeline. Peak of \(pct)% at \(peak?.time ?? "")."
        }

        var body: some View {
            GeometryReader { geo in
                let barWidth = max(4, (geo.size.width - CGFloat(hourly.count - 1) * 3) / CGFloat(hourly.count))
                HStack(alignment: .bottom, spacing: 3) {
                    ForEach(hourly) { hour in
                        let height = max(2, geo.size.height * hour.precipitationProbability)
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(Color.white.opacity(hour.precipitationProbability > 0.3 ? 0.85 : 0.25))
                            .frame(width: barWidth, height: height)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Precipitation probability mini chart")
            .accessibilityValue(chartSummary)
        }
    }

    struct TemperatureBarChart: View {
        let hourly: [HourlyWeather]
        @Environment(\.weatherFormatter) private var weatherFormatter

        private var chartSummary: String {
            guard !hourly.isEmpty else { return "No temperature data" }
            let temps = hourly.map(\.temperature)
            let minT = weatherFormatter.temp(temps.min() ?? 0)
            let maxT = weatherFormatter.temp(temps.max() ?? 0)
            return "Temperature trend ranging from \(minT) to \(maxT)"
        }

        var body: some View {
            GeometryReader { geo in
                let temps = hourly.map(\.temperature)
                let minT = (temps.min() ?? 20) - 2
                let maxT = (temps.max() ?? 35) + 2
                let range = max(1, maxT - minT)
                let barWidth = max(4, (geo.size.width - CGFloat(hourly.count - 1) * 3) / CGFloat(hourly.count))

                HStack(alignment: .bottom, spacing: 3) {
                    ForEach(hourly) { hour in
                        let normalized = (hour.temperature - minT) / range
                        let height = max(4, geo.size.height * normalized)
                        let isNow = hour.id == hourly.first?.id
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(isNow ? AppTheme.accent : Color.white.opacity(0.35))
                            .frame(width: barWidth, height: height)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Temperature trend mini chart")
            .accessibilityValue(chartSummary)
        }
    }

    struct WindLineChart: View {
        let hourly: [HourlyWeather]
        @Environment(\.weatherFormatter) private var weatherFormatter

        private var chartSummary: String {
            guard !hourly.isEmpty else { return "No wind data" }
            let maxSpeed = hourly.map(\.windSpeed).max() ?? 0
            return "Wind speed trend with peak sustained wind of \(weatherFormatter.wind(maxSpeed))"
        }

        var body: some View {
            GeometryReader { geo in
                let windSpeeds: [Double] = hourly.isEmpty ? [10, 10] : hourly.map(\.windSpeed)
                let peakWind = hourly.map { max($0.windSpeed, $0.windGust) }.max() ?? 20
                let maxWind: Double = max(30, ((peakWind / 10).rounded(.up)) * 10)
                let count = max(2, windSpeeds.count)
                let stepX = geo.size.width / CGFloat(count - 1)

                // Grid lines and reference levels (passing 3.0:1)
                ForEach([0, Int(maxWind / 2), Int(maxWind)], id: \.self) { value in
                    let y = geo.size.height * (1 - CGFloat(value) / maxWind)
                    HStack(spacing: 4) {
                        Rectangle()
                            .fill(AppTheme.chartGrid)
                            .frame(height: 1)
                        Text("\(value) km/h")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(AppTheme.chartAxisLabel)
                    }
                    .offset(y: y - 6)
                }

                // Line path
                Path { path in
                    for (index, speed) in windSpeeds.enumerated() {
                        let x = CGFloat(index) * stepX
                        let y = geo.size.height * (1 - speed / maxWind)
                        if index == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(Color.white.opacity(0.85), lineWidth: 2)

                // Fill under the line
                Path { path in
                    for (index, speed) in windSpeeds.enumerated() {
                        let x = CGFloat(index) * stepX
                        let y = geo.size.height * (1 - speed / maxWind)
                        if index == 0 {
                            path.move(to: CGPoint(x: 0, y: geo.size.height))
                            path.addLine(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                    path.addLine(to: CGPoint(x: CGFloat(windSpeeds.count - 1) * stepX, y: geo.size.height))
                    path.closeSubpath()
                }
                .fill(Color.white.opacity(0.10))
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Wind speed trend mini chart")
            .accessibilityValue(chartSummary)
        }
    }

    struct OutdoorTimeline: View {
        let hourly: [HourlyWeather]
        let outdoor: InsightEngine.BestOutdoorWindowResult

        private var chartSummary: String {
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_US")
            f.dateFormat = "ha"
            let s = f.string(from: outdoor.startDate).lowercased()
            let e = f.string(from: outdoor.endDate).lowercased()
            return "Best outdoor window from \(s) to \(e) with average temperature of \(Int(outdoor.averageTemperature.rounded())) degrees"
        }

        var body: some View {
            VStack(spacing: 8) {
                GeometryReader { geo in
                    let total = max(1, CGFloat(outdoor.totalCount))
                    let startOffset: CGFloat = max(0, min(1, CGFloat(outdoor.startIndex) / total))
                    let endOffset: CGFloat = max(0, min(1, CGFloat(outdoor.endIndex + 1) / total))
                    let windowWidth = max(8, (endOffset - startOffset) * geo.size.width)

                    ZStack(alignment: .leading) {
                        // Background track
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.white.opacity(0.08))

                        // Highlighted window
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.white.opacity(0.35))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .stroke(Color.white.opacity(0.50), lineWidth: 1)
                            )
                            .frame(width: windowWidth)
                            .offset(x: startOffset * geo.size.width)
                    }
                }
                .frame(height: 18)

                // Time labels based on the actual hourly window
                if !hourly.isEmpty {
                    HourlyTimeLabels(hourly: hourly)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Best outdoor activity timeline")
            .accessibilityValue(chartSummary)
        }
    }

    struct UVBarChart: View {
        let hourly: [HourlyWeather]

        private var chartSummary: String {
            let maxUV = hourly.map(\.uvIndex).max() ?? 0
            return "UV Index timeline with peak index of \(maxUV)"
        }

        var body: some View {
            GeometryReader { geo in
                let uvValues: [Double] = hourly.isEmpty ? [0, 0] : hourly.map { Double($0.uvIndex) }
                let maxUV: Double = max(11, (uvValues.max() ?? 10) + 1)
                let barWidth = max(4, (geo.size.width - CGFloat(max(1, uvValues.count - 1)) * 3) / CGFloat(max(1, uvValues.count)))

                HStack(alignment: .bottom, spacing: 3) {
                    ForEach(Array(uvValues.enumerated()), id: \.offset) { _, uv in
                        let height = max(2, geo.size.height * (uv / maxUV))
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(Color.white.opacity(uv >= 6 ? 0.85 : 0.30))
                            .frame(width: barWidth, height: height)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("UV index forecast mini chart")
            .accessibilityValue(chartSummary)
        }
    }

    struct CloudCoverChart: View {
        let hourly: [HourlyWeather]
        let shiftIndex: Int

        private var chartSummary: String {
            let avgCloud = hourly.isEmpty ? 0 : Int(hourly.map(\.cloudCover).reduce(0, +) / Double(max(1, hourly.count)) * 100)
            return "Cloud cover timeline averaging \(avgCloud)%"
        }

        var body: some View {
            VStack(spacing: 8) {
                GeometryReader { geo in
                    let maxVal: Double = 100
                    let labelWidth: CGFloat = 28
                    let chartWidth = max(10, geo.size.width - labelWidth)
                    let cloudPercent: [Double] = hourly.isEmpty ? [50, 50] : hourly.map { $0.cloudCover * 100 }
                    let barWidth = max(4, (chartWidth - CGFloat(max(1, cloudPercent.count - 1)) * 3) / CGFloat(max(1, cloudPercent.count)))

                    ZStack(alignment: .topLeading) {
                        // Grid references inside the chart width (passing 3.0:1)
                        ForEach([0, 50, 100], id: \.self) { value in
                            let y = geo.size.height * (1 - CGFloat(value) / maxVal)
                            HStack(spacing: 4) {
                                Rectangle()
                                    .fill(AppTheme.chartGrid)
                                    .frame(height: 1)
                                Text("\(value)%")
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(AppTheme.chartAxisLabel)
                                    .frame(width: labelWidth - 4, alignment: .trailing)
                            }
                            .offset(y: y - 5)
                        }

                        HStack(alignment: .bottom, spacing: 3) {
                            ForEach(Array(cloudPercent.enumerated()), id: \.offset) { index, pct in
                                let height = max(2, geo.size.height * (pct / maxVal))
                                let isShifted = index >= shiftIndex && shiftIndex > 0
                                RoundedRectangle(cornerRadius: 2, style: .continuous)
                                    .fill(isShifted ? Color.white.opacity(0.85) : Color.white.opacity(0.38))
                                    .overlay(
                                        // Series differentiation with border pattern: shifted overcast has prominent dashed/solid border
                                        Group {
                                            if isShifted {
                                                RoundedRectangle(cornerRadius: 2, style: .continuous)
                                                    .stroke(Color.white, lineWidth: 1.2)
                                            }
                                        }
                                    )
                                    .frame(width: barWidth, height: height)
                            }
                        }
                        .frame(width: chartWidth, height: geo.size.height, alignment: .bottomLeading)
                    }
                }
                .frame(height: 64)

                // Dynamic time labels matching the actual hours
                if !hourly.isEmpty {
                    HourlyTimeLabels(hourly: hourly)
                        .padding(.trailing, 28)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Cloud cover forecast mini chart")
            .accessibilityValue(chartSummary)
        }
    }
}
