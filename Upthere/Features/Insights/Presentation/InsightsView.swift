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
            bestOutdoorCard()

            // Highest UV
            highestUVCard(weather: weather)

            // Weather changing
            weatherChangingCard()
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

                Text("Highest precipitation probability around 5 PM (70%).")
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
        InsightCard {
            VStack(alignment: .leading, spacing: 8) {
                InsightBadge(icon: "wind", color: .mint, label: "Wind conditions")

                Text("Current & Gusts")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)

                let currentWindStr = WeatherFormatter.shared.wind(weather.windSpeed)
                let gustWindStr = WeatherFormatter.shared.wind(weather.windSpeed + 12)
                Text("Expected sustained wind: \(currentWindStr)\nPeak gusts: up to \(gustWindStr)")
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

                WindLineChart()
                    .frame(height: 80)

                HourlyTimeLabels(hourly: weather.hourlyForecast)
            }
        }
    }

    // MARK: - Best Outdoor Conditions Card

    private func bestOutdoorCard() -> some View {
        InsightCard {
            VStack(alignment: .leading, spacing: 8) {
                InsightBadge(icon: "sun.max.fill", color: .yellow, label: "Best outdoor conditions")

                Text("8:00 AM – 11:00 AM")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)

                Text("Comfortable temperature, low precipitation probability and moderate wind.")
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

                OutdoorTimeline()
                    .padding(.top, 4)
            }
        }
    }

    // MARK: - Highest UV Card

    private func highestUVCard(weather: Weather) -> some View {
        InsightCard {
            VStack(alignment: .leading, spacing: 8) {
                InsightBadge(icon: "sun.max.fill", color: .purple, label: "Highest UV")

                Text("12 PM – 2 PM")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)

                Text("UV Index: \(weather.uvIndex + 5) · High")
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

                UVBarChart()
                    .frame(height: 80)

                HourlyTimeLabels(hourly: weather.hourlyForecast)
            }
        }
    }

    // MARK: - Weather Changing Card

    private func weatherChangingCard() -> some View {
        InsightCard {
            VStack(alignment: .leading, spacing: 8) {
                InsightBadge(icon: "cloud.sun.fill", color: .teal, label: "Weather changing")

                Text("After 2 PM")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)

                Text("Cloud cover increases significantly, from 45% to 90%.")
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineSpacing(2)

                CloudCoverChart()
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
    // Synthetic wind data over 16 hours
    private let windSpeeds: [Double] = [10, 11, 13, 15, 17, 19, 22, 24, 20, 16, 14, 12, 11, 10, 9, 8]

    var body: some View {
        GeometryReader { geo in
            let maxWind: Double = 40
            let stepX = geo.size.width / CGFloat(windSpeeds.count - 1)

            // Grid lines
            ForEach([0, 20, 40], id: \.self) { value in
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

private struct OutdoorTimeline: View {
    var body: some View {
        VStack(spacing: 8) {
            GeometryReader { geo in
                let totalHours: CGFloat = 16 // 6 AM to 10 PM
                let startOffset: CGFloat = 2 / totalHours  // 8 AM
                let endOffset: CGFloat = 5 / totalHours    // 11 AM

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
                        .frame(width: (endOffset - startOffset) * geo.size.width)
                        .offset(x: startOffset * geo.size.width)
                }
            }
            .frame(height: 18)

            // Time labels
            HStack {
                Text("6 AM")
                    .font(.system(size: 10))
                    .foregroundStyle(AppTheme.textTertiary)
                Spacer()
                Text("12 PM")
                    .font(.system(size: 10))
                    .foregroundStyle(AppTheme.textTertiary)
                Spacer()
                Text("6 PM")
                    .font(.system(size: 10))
                    .foregroundStyle(AppTheme.textTertiary)
                Spacer()
                Text("11 PM")
                    .font(.system(size: 10))
                    .foregroundStyle(AppTheme.textTertiary)
            }
        }
    }
}

private struct UVBarChart: View {
    // Synthetic UV data: 16 hours from 8a to 11p
    private let uvValues: [Double] = [1, 2, 3, 5, 7, 9, 11, 12, 10, 7, 4, 2, 1, 0, 0, 0]

    var body: some View {
        GeometryReader { geo in
            let maxUV: Double = 14
            let barWidth = max(4, (geo.size.width - CGFloat(uvValues.count - 1) * 3) / CGFloat(uvValues.count))

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
    // Synthetic cloud cover data: 16 hours
    private let cloudPercent: [Double] = [30, 35, 40, 42, 45, 48, 55, 65, 75, 82, 88, 90, 88, 85, 80, 75]

    var body: some View {
        VStack(spacing: 8) {
            GeometryReader { geo in
                let maxVal: Double = 100
                let labelWidth: CGFloat = 28
                let chartWidth = max(10, geo.size.width - labelWidth)
                let barWidth = max(4, (chartWidth - CGFloat(cloudPercent.count - 1) * 3) / CGFloat(cloudPercent.count))

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
                            let isAfter2PM = index >= 6
                            RoundedRectangle(cornerRadius: 2, style: .continuous)
                                .fill(isAfter2PM ? Color.gray.opacity(0.7) : Color.gray.opacity(0.3))
                                .frame(width: barWidth, height: height)
                        }
                    }
                    .frame(width: chartWidth, height: geo.size.height, alignment: .bottomLeading)
                }
            }
            .frame(height: 64)

            // Time labels
            HStack(spacing: 0) {
                Text("8 AM")
                Spacer()
                Text("12 PM")
                Spacer()
                Text("4 PM")
                Spacer()
                Text("11 PM")
            }
            .font(.system(size: 10))
            .foregroundStyle(AppTheme.textTertiary)
            .padding(.trailing, 28)
        }
    }
}

#Preview {
    let repo = MockWeatherRepository()
    let uc = GetWeatherUseCase(repository: repo)
    let vm = HomeViewModel(getWeatherUseCase: uc)
    InsightsView(viewModel: vm)
}
