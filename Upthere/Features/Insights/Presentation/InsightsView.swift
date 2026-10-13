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
            case .loaded(let weather, _):
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        header
                        alertSection(weather: weather)
                        insightsSection(weather: weather)
                        footer
                    }
                    .padding(.bottom, 120)
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
                    .foregroundStyle(Color(red: 0.65, green: 0.85, blue: 1.0))
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

    private func insightsSection(weather: Weather) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("UpThere insights")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 20)

            // Rain window
            if let rain = weather.rainWindow {
                rainWindowCard(rain: rain, hourly: weather.hourlyForecast)
            }

            // Temperature rising
            temperatureRisingCard(weather: weather)

            // Strongest winds
            strongestWindsCard(weather: weather)

            // Best outdoor conditions
            bestOutdoorCard(weather: weather)

            // Highest UV
            highestUVCard(weather: weather)

            // Weather changing
            weatherChangingCard(weather: weather)
        }
    }

    // MARK: - Rain Window Card

    private func rainWindowCard(rain: RainWindow, hourly: [HourlyWeather]) -> some View {
        InsightCard {
            VStack(alignment: .leading, spacing: 8) {
                InsightBadge(icon: "cloud.rain.fill", color: .cyan, label: "Rain window")

                Text(rain.timeRange)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)

                let peakHour = hourly.max(by: { $0.precipitationProbability < $1.precipitationProbability })
                let peakProb = Int(((peakHour?.precipitationProbability ?? 0.0) * 100).rounded())
                let precipDetail: String = {
                    guard let peak = peakHour, peakProb > 0 else { return rain.detail }
                    if peak.time.lowercased() == "now" {
                        return "Highest precipitation probability right now (\(peakProb)%)."
                    } else {
                        return "Highest precipitation probability around \(peak.time) (\(peakProb)%)."
                    }
                }()

                Text(precipDetail)
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineSpacing(2)

                // Now indicator
                HStack(spacing: 4) {
                    Text("Now")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppTheme.textTertiary)
                    let precipProb = Int(((hourly.first?.precipitationProbability ?? 0.0) * 100).rounded())
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

    private func temperatureRisingCard(weather: Weather) -> some View {
        InsightCard {
            VStack(alignment: .leading, spacing: 8) {
                InsightBadge(icon: "thermometer.sun.fill", color: .orange, label: "Temperature range")

                HStack(spacing: 4) {
                    Text(WeatherFormatter.shared.temp(weather.lowTemperature))
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.white)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                    Text(WeatherFormatter.shared.temp(weather.highTemperature))
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.white)
                }

                Text("Expected temperature swing from daily low to peak high.")
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineSpacing(2)

                HStack(spacing: 4) {
                    Text("Now")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppTheme.textTertiary)
                    Text(WeatherFormatter.shared.temp(weather.temperature))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .padding(.top, 4)

                TemperatureBarChart(hourly: weather.hourlyForecast)
                    .frame(height: 80)

                HourlyTimeLabels(hourly: weather.hourlyForecast)
            }
        }
    }

    // MARK: - Strongest Winds Card

    private func strongestWindsCard(weather: Weather) -> some View {
        let hourly = weather.hourlyForecast
        let currentWindStr = WeatherFormatter.shared.wind(weather.windSpeed)
        let maxGustValue = hourly.map { max($0.windGust, $0.windSpeed) }.max() ?? weather.windSpeed
        let gustWindStr = WeatherFormatter.shared.wind(maxGustValue)
        let maxWindHour = hourly.max(by: { $0.windGust < $1.windGust })

        let windDetail: String = {
            if let maxHour = maxWindHour, maxGustValue > weather.windSpeed {
                let timeStr = maxHour.time.lowercased() == "now" ? "right now" : "around \(maxHour.time)"
                return "Expected sustained wind: \(currentWindStr)\nPeak gusts: up to \(gustWindStr) \(timeStr)"
            } else {
                return "Expected sustained wind: \(currentWindStr)\nPeak gusts: up to \(gustWindStr)"
            }
        }()

        return InsightCard {
            VStack(alignment: .leading, spacing: 8) {
                InsightBadge(icon: "wind", color: .mint, label: "Wind conditions")

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

    private func calculateBestOutdoorWindow(from hourly: [HourlyWeather]) -> OutdoorWindow {
        guard !hourly.isEmpty else {
            return OutdoorWindow(timeRange: "Morning – Afternoon", detail: "Comfortable conditions expected today.", startIndex: 0, endIndex: 0, totalCount: 1)
        }

        func hourScore(_ hour: HourlyWeather) -> Double {
            var s = 100.0
            // Heavy penalty for rain
            s -= hour.precipitationProbability * 80.0
            // Comfort temp curve (optimal 18-25 C)
            if hour.temperature < 18 {
                s -= (18 - hour.temperature) * 3.0
            } else if hour.temperature > 25 {
                s -= (hour.temperature - 25) * 3.0
            }
            // Wind penalty
            if hour.windSpeed > 20 {
                s -= (hour.windSpeed - 20) * 1.5
            }
            // UV penalty
            if hour.uvIndex > 7 {
                s -= Double(hour.uvIndex - 7) * 4.0
            }
            return s
        }

        let windowSize = min(3, hourly.count)
        var bestScore = -Double.infinity
        var bestStart = 0
        var bestEnd = max(0, windowSize - 1)

        if hourly.count >= windowSize {
            for i in 0...(hourly.count - windowSize) {
                let slice = hourly[i..<(i + windowSize)]
                let avg = slice.map { hourScore($0) }.reduce(0, +) / Double(windowSize)
                if avg > bestScore {
                    bestScore = avg
                    bestStart = i
                    bestEnd = i + windowSize - 1
                }
            }
        }

        let startHour = hourly[bestStart]
        let endHour = hourly[bestEnd]
        let timeRange = startHour.time == endHour.time ? "Around \(startHour.time)" : "\(startHour.time) – \(endHour.time)"

        let windowSlice = hourly[bestStart...bestEnd]
        let maxRain = Int(((windowSlice.map(\.precipitationProbability).max() ?? 0) * 100).rounded())
        let avgWind = Int((windowSlice.map(\.windSpeed).reduce(0, +) / Double(windowSlice.count)).rounded())

        let detail: String
        if maxRain > 40 {
            detail = "Most favorable available window despite \(maxRain)% rain chance and \(avgWind) km/h wind."
        } else {
            detail = "Comfortable temperature, low precipitation probability (\(maxRain)%) and moderate wind (\(avgWind) km/h)."
        }

        return OutdoorWindow(
            timeRange: timeRange,
            detail: detail,
            startIndex: bestStart,
            endIndex: bestEnd,
            totalCount: hourly.count
        )
    }

    private func bestOutdoorCard(weather: Weather) -> some View {
        let outdoorWindow = calculateBestOutdoorWindow(from: weather.hourlyForecast)

        return InsightCard {
            VStack(alignment: .leading, spacing: 8) {
                InsightBadge(icon: "sun.max.fill", color: .yellow, label: "Best outdoor conditions")

                Text(outdoorWindow.timeRange)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)

                Text(outdoorWindow.detail)
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

                OutdoorTimeline(hourly: weather.hourlyForecast, outdoorWindow: outdoorWindow)
                    .padding(.top, 4)
            }
        }
    }

    // MARK: - Highest UV Card

    private func highestUVCard(weather: Weather) -> some View {
        let hourly = weather.hourlyForecast
        let maxUVHour = hourly.max(by: { $0.uvIndex < $1.uvIndex })
        let peakUV = max(weather.uvIndex, maxUVHour?.uvIndex ?? weather.uvIndex)

        // Find hours where UV is within 1 of peak (and > 0)
        let peakHours = hourly.filter { $0.uvIndex >= max(1, peakUV - 1) && $0.uvIndex > 0 }
        let timeRange: String = {
            if let first = peakHours.first, let last = peakHours.last {
                return first.time == last.time ? "Around \(first.time)" : "\(first.time) – \(last.time)"
            }
            if let maxHour = maxUVHour {
                return "Around \(maxHour.time)"
            }
            return "Midday"
        }()

        let uvCategoryStr = uvCategory(for: peakUV)

        return InsightCard {
            VStack(alignment: .leading, spacing: 8) {
                InsightBadge(icon: "sun.max.fill", color: .purple, label: "Highest UV")

                Text(timeRange)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)

                Text("UV Index: \(peakUV) · \(uvCategoryStr)")
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.textSecondary)

                HStack(spacing: 4) {
                    Text("Now")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppTheme.textTertiary)
                    Text("\(weather.uvIndex)")
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

    private struct WeatherShiftInfo {
        let heading: String
        let description: String
        let shiftIndex: Int
    }

    private func calculateWeatherShift(from hourly: [HourlyWeather], fallbackCondition: String) -> WeatherShiftInfo {
        guard !hourly.isEmpty else {
            return WeatherShiftInfo(heading: "Today", description: "Conditions expected to remain steady.", shiftIndex: 0)
        }

        let clouds = hourly.map { $0.cloudCover * 100 }
        let minCloud = clouds.min() ?? 0
        let maxCloud = clouds.max() ?? 0
        let diff = maxCloud - minCloud

        if diff >= 20 {
            var maxChange = 0.0
            var shiftIdx = 1
            for i in 1..<hourly.count {
                let change = abs(clouds[i] - clouds[i - 1])
                if change > maxChange {
                    maxChange = change
                    shiftIdx = i
                }
            }

            let hourName = hourly[shiftIdx].time
            let heading = hourName.lowercased() == "now" ? "Starting now" : "After \(hourName)"

            if (clouds.last ?? 0) >= (clouds.first ?? 0) {
                let startPct = Int(clouds.first?.rounded() ?? 0)
                let endPct = Int(maxCloud.rounded())
                return WeatherShiftInfo(
                    heading: heading,
                    description: "Cloud cover increases significantly, from \(startPct)% to \(endPct)%.",
                    shiftIndex: shiftIdx
                )
            } else {
                let startPct = Int(maxCloud.rounded())
                let endPct = Int(minCloud.rounded())
                return WeatherShiftInfo(
                    heading: heading,
                    description: "Skies clearing as cloud cover drops from \(startPct)% to \(endPct)%.",
                    shiftIndex: shiftIdx
                )
            }
        }

        // If cloud cover is steady, check precipitation or condition changes
        if let firstRain = hourly.first(where: { $0.precipitationProbability >= 0.4 }) {
            let pct = Int((firstRain.precipitationProbability * 100).rounded())
            return WeatherShiftInfo(
                heading: firstRain.time.lowercased() == "now" ? "Rain starting" : "Around \(firstRain.time)",
                description: "Rain chances increase to \(pct)%.",
                shiftIndex: hourly.firstIndex(where: { $0.id == firstRain.id }) ?? 0
            )
        }

        let avgCloud = Int((clouds.reduce(0, +) / Double(clouds.count)).rounded())
        return WeatherShiftInfo(
            heading: "Steady conditions",
            description: "Skies remain consistently \(fallbackCondition.lowercased()) with ~\(avgCloud)% cloud cover.",
            shiftIndex: 0
        )
    }

    private func weatherChangingCard(weather: Weather) -> some View {
        let shiftInfo = calculateWeatherShift(from: weather.hourlyForecast, fallbackCondition: weather.condition)

        return InsightCard {
            VStack(alignment: .leading, spacing: 8) {
                InsightBadge(icon: "cloud.sun.fill", color: .teal, label: "Weather changing")

                Text(shiftInfo.heading)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)

                Text(shiftInfo.description)
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineSpacing(2)

                CloudCoverChart(hourly: weather.hourlyForecast, shiftIndex: shiftInfo.shiftIndex)
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
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(color)
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
                        .fill(
                            hour.precipitationProbability > 0.4
                                ? Color.cyan
                                : Color.cyan.opacity(0.4)
                        )
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
                        .fill(
                            LinearGradient(
                                colors: [Color.orange, Color.yellow],
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )
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
            .stroke(Color.mint, lineWidth: 2)

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
            .fill(
                LinearGradient(
                    colors: [Color.mint.opacity(0.3), Color.mint.opacity(0.0)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
    }
}

private struct OutdoorWindow {
    let timeRange: String
    let detail: String
    let startIndex: Int
    let endIndex: Int
    let totalCount: Int
}

private struct OutdoorTimeline: View {
    let hourly: [HourlyWeather]
    let outdoorWindow: OutdoorWindow

    var body: some View {
        VStack(spacing: 8) {
            GeometryReader { geo in
                let total = max(1, CGFloat(outdoorWindow.totalCount))
                let startOffset: CGFloat = max(0, min(1, CGFloat(outdoorWindow.startIndex) / total))
                let endOffset: CGFloat = max(0, min(1, CGFloat(outdoorWindow.endIndex + 1) / total))
                let windowWidth = max(8, (endOffset - startOffset) * geo.size.width)

                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.white.opacity(0.08))

                    // Highlighted window
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.green.opacity(0.6), Color.yellow.opacity(0.5)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
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
                        .fill(uvColor(for: uv))
                        .frame(width: barWidth, height: height)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        }
    }

    private func uvColor(for value: Double) -> Color {
        if value >= 8 { return .red.opacity(0.9) }
        if value >= 6 { return .orange }
        if value >= 3 { return .yellow }
        return .green.opacity(0.6)
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
                                .fill(isShifted ? Color.teal.opacity(0.7) : Color.gray.opacity(0.4))
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
