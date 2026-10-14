import SwiftUI

public struct InsightsView: View {
    @State private var viewModel: HomeViewModel

    public init(viewModel: HomeViewModel) {
        self._viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        ZStack {
            WeatherBackgroundView(
                condition: viewModel.displayedWeather?.condition,
                symbolName: viewModel.displayedWeather?.weatherSymbolName
            )

            if let weather = viewModel.displayedWeather {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        header
                        alertSection(weather: weather)
                        insightsSection(weather: weather)
                        footer
                    }
                    .padding(.bottom, 120)
                }
            } else {
                switch viewModel.state {
                case .idle, .loading:
                    ProgressView().tint(.white)
                case .error(let msg, _):
                    VStack(spacing: 8) {
                        Text(msg)
                            .foregroundStyle(AppTheme.textSecondary)
                        Button("Retry") {
                            Task { await viewModel.refreshWeather() }
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.accent)
                    }
                    .padding(.horizontal, 20)
                case .loaded:
                    ProgressView().tint(.white)
                }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Insights")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(.white)
            Text("What the forecast actually means.")
                .font(.system(size: 16))
                .foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 62)
        .padding(.bottom, 28)
    }

    // MARK: - Weather Alerts

    private func alertSection(weather: Weather) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Weather alerts")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                Spacer()
                Text("Official source")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .padding(.horizontal, 20)

            if let alert = weather.alert {
                VStack(alignment: .leading, spacing: 12) {
                    // Badge
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(AppTheme.alertAmber)
                        Text(alert.severity != nil ? "\(alert.severity?.capitalized ?? "") Weather Alert" : "Official weather alert")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(AppTheme.textSecondary)
                    }

                    // Title
                    Text(alert.title)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)

                    // Description
                    if let details = alert.details, !details.isEmpty {
                        Text(details)
                            .font(.system(size: 14))
                            .foregroundStyle(AppTheme.textSecondary)
                            .lineSpacing(3)
                    }

                    // Source
                    let sourceText = alert.source.isEmpty ? "Meteorological Agency" : alert.source
                    Text("Issued by \(sourceText) · \(alert.validUntil)")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.textTertiary)
                        .lineSpacing(2)

                    Rectangle()
                        .fill(Color.white.opacity(0.10))
                        .frame(height: 1)

                    // Attribution link
                    HStack {
                        Text("Read official attribution")
                            .font(.system(size: 14))
                            .foregroundStyle(.white)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AppTheme.textTertiary)
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(AppTheme.cardGlass)
                )
                .padding(.horizontal, 20)
            } else {
                // No active alerts state card
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Color.green.opacity(0.85))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("No active weather alerts")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                        Text("No severe weather warnings are currently in effect for this region.")
                            .font(.system(size: 13))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    Spacer()
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(AppTheme.cardGlass)
                )
                .padding(.horizontal, 20)
            }
        }
        .padding(.bottom, 28)
    }

    // MARK: - UpThere Insights

    private let insightEngine = InsightEngine()

    private func formatHour(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "ha"
        return formatter.string(from: date).lowercased().replacingOccurrences(of: "m", with: "")
    }

    private func formatTimeRange(start: Date, end: Date) -> String {
        let s = formatHour(start)
        let e = formatHour(end)
        return s == e ? "Around \(s)" : "\(s) – \(e)"
    }

    private func insightsSection(weather: Weather) -> some View {
        let hourly = weather.hourlyForecast
        let rainWindow = insightEngine.rainWindow(from: hourly)
        let tempTrend = insightEngine.temperatureTrend(from: hourly)
        let strongWind = insightEngine.strongestWind(from: hourly)
        let outdoorWindow = insightEngine.bestOutdoorWindow(from: hourly)
        let peakUV = insightEngine.peakUV(from: hourly)
        let cloudChange = insightEngine.cloudChange(from: hourly)

        return VStack(alignment: .leading, spacing: 16) {
            Text("UpThere insights")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 20)

            if let rain = rainWindow {
                rainWindowCard(rain: rain, hourly: hourly)
            }

            if let trend = tempTrend {
                temperatureRisingCard(trend: trend, hourly: hourly)
            }

            if let wind = strongWind {
                strongestWindsCard(wind: wind, hourly: hourly)
            }

            if let outdoor = outdoorWindow {
                bestOutdoorCard(outdoor: outdoor, hourly: hourly)
            }

            if let uv = peakUV {
                highestUVCard(uv: uv, currentUV: weather.uvIndex, hourly: hourly)
            }

            if let cloud = cloudChange {
                weatherChangingCard(cloud: cloud, hourly: hourly)
            }
        }
    }

    // MARK: - Rain Window Card

    private func rainWindowCard(rain: InsightEngine.RainWindowResult, hourly: [HourlyWeather]) -> some View {
        InsightCard {
            VStack(alignment: .leading, spacing: 8) {
                InsightBadge(icon: "cloud.rain.fill", label: "Rain window")

                Text(formatTimeRange(start: rain.startDate, end: rain.endDate))
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)

                let peakProb = Int((rain.peakProbability * 100).rounded())
                let peakTime = formatHour(rain.peakDate)
                let precipDetail = "Peak precipitation around \(peakTime), \(peakProb)% probability."

                Text(precipDetail)
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineSpacing(2)

                // Now indicator
                HStack(spacing: 4) {
                    Text("Now")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppTheme.textTertiary)
                    let precipProb = Int(((hourly.first?.precipitationChance ?? 0.0) * 100).rounded())
                    Text("\(precipProb)%")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                    Spacer()
                    Text("100%")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.textTertiary)
                }
                .padding(.top, 4)

                // Precipitation bar chart
                PrecipitationBarChart(hourly: hourly)
                    .frame(height: 80)

                // Time labels
                HourlyTimeLabels(hourly: hourly)
            }
        }
    }

    // MARK: - Temperature Rising Card

    private func temperatureRisingCard(trend: InsightEngine.TemperatureTrendResult, hourly: [HourlyWeather]) -> some View {
        InsightCard {
            VStack(alignment: .leading, spacing: 8) {
                InsightBadge(icon: "thermometer.sun.fill", label: "Temperature range")

                HStack(spacing: 4) {
                    Text(WeatherFormatter.shared.temp(trend.minTemperature))
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.white)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                    Text(WeatherFormatter.shared.temp(trend.maxTemperature))
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.white)
                }

                Text("Expected temperature swing of \(Int(trend.temperatureSwing.rounded()))° between \(formatHour(trend.minDate)) and \(formatHour(trend.maxDate)).")
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineSpacing(2)

                HStack(spacing: 4) {
                    Text("Now")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppTheme.textTertiary)
                    Text(WeatherFormatter.shared.temp(trend.currentTemperature))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .padding(.top, 4)

                TemperatureBarChart(hourly: hourly)
                    .frame(height: 80)

                HourlyTimeLabels(hourly: hourly)
            }
        }
    }

    // MARK: - Strongest Winds Card

    private func strongestWindsCard(wind: InsightEngine.StrongestWindResult, hourly: [HourlyWeather]) -> some View {
        let currentWindStr = WeatherFormatter.shared.wind(wind.currentWindSpeed)
        let gustWindStr = WeatherFormatter.shared.wind(wind.peakGust)
        let peakTime = formatHour(wind.peakDate)

        let windDetail: String = {
            if wind.peakGust > wind.currentWindSpeed {
                return "Expected sustained wind: \(currentWindStr)\nPeak gusts: up to \(gustWindStr) around \(peakTime)"
            } else {
                return "Expected sustained wind: \(currentWindStr)\nPeak gusts: up to \(gustWindStr)"
            }
        }()

        return InsightCard {
            VStack(alignment: .leading, spacing: 8) {
                InsightBadge(icon: "wind", label: "Wind conditions")

                Text("Current & Gusts")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)

                Text(windDetail)
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineSpacing(2)

                HStack(spacing: 4) {
                    Text("Now")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppTheme.textTertiary)
                    Text(currentWindStr)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .padding(.top, 4)

                WindLineChart(hourly: hourly)
                    .frame(height: 80)

                HourlyTimeLabels(hourly: hourly)
            }
        }
    }

    // MARK: - Best Outdoor Conditions Card

    private func bestOutdoorCard(outdoor: InsightEngine.BestOutdoorWindowResult, hourly: [HourlyWeather]) -> some View {
        let maxRain = Int((outdoor.maxPrecipitationChance * 100).rounded())
        let avgWind = Int(outdoor.averageWindSpeed.rounded())
        let avgTemp = Int(outdoor.averageTemperature.rounded())

        let detail: String = {
            if maxRain > 40 {
                return "Most favorable available window despite \(maxRain)% rain chance and \(avgWind) km/h wind."
            } else {
                return "Comfortable ~\(avgTemp)°, low precipitation probability (\(maxRain)%) and moderate wind (\(avgWind) km/h)."
            }
        }()

        return InsightCard {
            VStack(alignment: .leading, spacing: 8) {
                InsightBadge(icon: "sun.max.fill", label: "Best outdoor conditions")

                Text(formatTimeRange(start: outdoor.startDate, end: outdoor.endDate))
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)

                Text(detail)
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineSpacing(2)

                // Now indicator
                HStack(spacing: 4) {
                    Text("Now")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppTheme.textTertiary)
                }
                .padding(.top, 4)

                OutdoorTimeline(hourly: hourly, outdoor: outdoor)
                    .padding(.top, 4)
            }
        }
    }

    // MARK: - Highest UV Card

    private func highestUVCard(uv: InsightEngine.PeakUVResult, currentUV: Int, hourly: [HourlyWeather]) -> some View {
        let timeRange = formatTimeRange(start: uv.startDate, end: uv.endDate)
        let uvCategoryStr = uvCategory(for: uv.peakUVIndex)

        return InsightCard {
            VStack(alignment: .leading, spacing: 8) {
                InsightBadge(icon: "sun.max.fill", label: "Highest UV")

                Text(timeRange)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)

                Text("UV Index: \(uv.peakUVIndex) · \(uvCategoryStr)")
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.textSecondary)

                HStack(spacing: 4) {
                    Text("Now")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppTheme.textTertiary)
                    Text("\(currentUV)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .padding(.top, 4)

                UVBarChart(hourly: hourly)
                    .frame(height: 80)

                HourlyTimeLabels(hourly: hourly)
            }
        }
    }

    private func uvCategory(for value: Int) -> String {
        switch value {
        case 0...2: return "Low"
        case 3...5: return "Moderate"
        case 6...7: return "High"
        case 8...10: return "Very High"
        default: return "Extreme"
        }
    }

    // MARK: - Weather Changing Card

    private func weatherChangingCard(cloud: InsightEngine.CloudChangeResult, hourly: [HourlyWeather]) -> some View {
        let heading = cloud.isClearing ? "Skies clearing" : "Cloud cover increasing"
        let startPct = Int((cloud.initialCloudCover * 100).rounded())
        let endPct = Int((cloud.targetCloudCover * 100).rounded())
        let timeStr = formatHour(cloud.changeDate)

        let description: String = {
            if cloud.isClearing {
                return "Skies clearing around \(timeStr) as cloud cover drops from \(startPct)% to \(endPct)%."
            } else {
                return "Cloud cover increases significantly around \(timeStr), from \(startPct)% to \(endPct)%."
            }
        }()

        return InsightCard {
            VStack(alignment: .leading, spacing: 8) {
                InsightBadge(icon: "cloud.sun.fill", label: "Weather changing")

                Text(heading)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)

                Text(description)
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineSpacing(2)

                CloudCoverChart(hourly: hourly, shiftIndex: cloud.changeIndex)
            }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        Text("Insights are UpThere's interpretation of forecast data and may change as forecasts update. For official warnings, refer to your national weather service.")
            .font(.system(size: 12))
            .foregroundStyle(AppTheme.textTertiary)
            .lineSpacing(3)
            .padding(.horizontal, 20)
            .padding(.top, 20)
    }
}

// MARK: - Reusable Components

private struct InsightCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading) {
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppTheme.cardGlass)
        )
        .padding(.horizontal, 20)
    }
}

private struct InsightBadge: View {
    let icon: String
    let label: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(Color.white.opacity(0.75))
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppTheme.textSecondary)
        }
        .padding(.bottom, 2)
    }
}

private struct HourlyTimeLabels: View {
    let hourly: [HourlyWeather]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(hourly.enumerated()), id: \.element.id) { index, hour in
                if index % 2 == 0 {
                    Text(hour.time)
                        .font(.system(size: 10))
                        .foregroundStyle(AppTheme.textTertiary)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }
}

// MARK: - Mini Charts

private struct PrecipitationBarChart: View {
    let hourly: [HourlyWeather]

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
    }
}

private struct TemperatureBarChart: View {
    let hourly: [HourlyWeather]

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
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(Color.white.opacity(hour.id == hourly.first?.id ? 0.90 : 0.35))
                        .frame(width: barWidth, height: height)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        }
    }
}

private struct WindLineChart: View {
    let hourly: [HourlyWeather]

    var body: some View {
        GeometryReader { geo in
            let windSpeeds: [Double] = hourly.isEmpty ? [10, 10] : hourly.map(\.windSpeed)
            let peakWind = hourly.map { max($0.windSpeed, $0.windGust) }.max() ?? 20
            let maxWind: Double = max(30, ((peakWind / 10).rounded(.up)) * 10)
            let count = max(2, windSpeeds.count)
            let stepX = geo.size.width / CGFloat(count - 1)

            // Grid lines
            ForEach([0, Int(maxWind / 2), Int(maxWind)], id: \.self) { value in
                let y = geo.size.height * (1 - CGFloat(value) / maxWind)
                HStack {
                    Spacer()
                    Text("\(value) km/h")
                        .font(.system(size: 9))
                        .foregroundStyle(AppTheme.textTertiary)
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
    }
}

private struct OutdoorTimeline: View {
    let hourly: [HourlyWeather]
    let outdoor: InsightEngine.BestOutdoorWindowResult

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
    }
}

private struct UVBarChart: View {
    let hourly: [HourlyWeather]

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
    }
}

private struct CloudCoverChart: View {
    let hourly: [HourlyWeather]
    let shiftIndex: Int

    var body: some View {
        VStack(spacing: 8) {
            GeometryReader { geo in
                let maxVal: Double = 100
                let labelWidth: CGFloat = 28
                let chartWidth = max(10, geo.size.width - labelWidth)
                let cloudPercent: [Double] = hourly.isEmpty ? [50, 50] : hourly.map { $0.cloudCover * 100 }
                let barWidth = max(4, (chartWidth - CGFloat(max(1, cloudPercent.count - 1)) * 3) / CGFloat(max(1, cloudPercent.count)))

                ZStack(alignment: .topLeading) {
                    // Grid references inside the chart width
                    ForEach([0, 50, 100], id: \.self) { value in
                        let y = geo.size.height * (1 - CGFloat(value) / maxVal)
                        HStack(spacing: 4) {
                            Rectangle()
                                .fill(Color.white.opacity(0.06))
                                .frame(height: 1)
                            Text("\(value)%")
                                .font(.system(size: 9))
                                .foregroundStyle(AppTheme.textTertiary)
                                .frame(width: labelWidth - 4, alignment: .trailing)
                        }
                        .offset(y: y - 5)
                    }

                    HStack(alignment: .bottom, spacing: 3) {
                        ForEach(Array(cloudPercent.enumerated()), id: \.offset) { index, pct in
                            let height = max(2, geo.size.height * (pct / maxVal))
                            let isShifted = index >= shiftIndex && shiftIndex > 0
                            RoundedRectangle(cornerRadius: 2, style: .continuous)
                                .fill(isShifted ? Color.white.opacity(0.80) : Color.white.opacity(0.25))
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
    }
}

#Preview {
    let repo = MockWeatherRepository()
    let uc = GetWeatherUseCase(repository: repo)
    let vm = HomeViewModel(getWeatherUseCase: uc)
    InsightsView(viewModel: vm)
}
