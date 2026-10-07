import SwiftUI

// MARK: - HomeView

public struct HomeView: View {
    @State private var viewModel: HomeViewModel
    public var onNavigateToInsights: (() -> Void)?

    public init(viewModel: HomeViewModel, onNavigateToInsights: (() -> Void)? = nil) {
        self._viewModel = State(initialValue: viewModel)
        self.onNavigateToInsights = onNavigateToInsights
    }

    public var body: some View {
        ZStack {
            AppTheme.backgroundGradient.ignoresSafeArea()

            switch viewModel.state {
            case .idle:
                Color.clear.onAppear { Task { await viewModel.loadWeather() } }

            case .loading:
                LoadingSkeletonView()

            case .loaded(let weather):
                WeatherScrollContent(weather: weather, onNavigateToInsights: onNavigateToInsights)

            case .error:
                NetworkErrorView {
                    Task { await viewModel.loadWeather() }
                }
            }
        }
        .task { await viewModel.loadWeather() }
    }
}

// MARK: - WeatherScrollContent

private struct WeatherScrollContent: View {
    let weather: Weather
    var onNavigateToInsights: (() -> Void)?

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                headerSection
                temperatureSection
                descriptionSection
                if let alert = weather.alert { alertSection(alert) }
                divider
                metricsGrid
                divider
                insightSection
                precipitationChart
                temperatureChart
                todaySection
                Spacer(minLength: 110)
            }
            .padding(.horizontal, 20)
            .padding(.top, 62)
        }
    }

    // MARK: Header
    private var headerSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text(weather.cityName)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                }
                Text(weather.locationSubtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            Spacer()
            Image(systemName: weather.weatherSymbolName)
                .symbolRenderingMode(.multicolor)
                .font(.system(size: 52))
        }
        .padding(.top, 8)
        .padding(.bottom, 20)
    }

    // MARK: Temperature
    private var temperatureSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(Int(weather.temperature))°")
                .font(.system(size: 88, weight: .thin, design: .rounded))
                .foregroundStyle(AppTheme.textPrimary)
                .tracking(-2)

            Text(weather.condition)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)

            Text("Feels like \(Int(weather.feelsLike))° · H \(Int(weather.highTemperature))° L \(Int(weather.lowTemperature))°")
                .font(.system(size: 15))
                .foregroundStyle(AppTheme.textSecondary)
        }
        .padding(.bottom, 16)
    }

    // MARK: Description
    private var descriptionSection: some View {
        Text(weather.description)
            .font(.system(size: 15))
            .foregroundStyle(AppTheme.textSecondary)
            .lineSpacing(4)
            .padding(.bottom, 20)
    }

    // MARK: Alert
    private func alertSection(_ alert: WeatherAlert) -> some View {
        Button {
            onNavigateToInsights?()
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(AppTheme.alertAmber)
                    .font(.system(size: 16))
                    .padding(.top, 2)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Official alert · \(alert.source)")
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.alertAmber)
                    Text(alert.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text(alert.validUntil)
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(AppTheme.textTertiary)
                    .font(.system(size: 14, weight: .medium))
                    .padding(.top, 2)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(AppTheme.alertAmber.opacity(0.6), lineWidth: 1)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(AppTheme.alertAmber.opacity(0.08))
                    )
            )
        }
        .buttonStyle(.plain)
        .padding(.bottom, 20)
    }

    // MARK: Divider
    private var divider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.12))
            .frame(height: 1)
            .padding(.bottom, 20)
    }

    // MARK: Metrics Grid
    private var metricsGrid: some View {
        let rows: [(String, String, String, String, String, String)] = [
            ("Humidity", "\(weather.humidity)%", "Dew point \(Int(weather.dewPoint))°",
             "Wind", "\(Int(weather.windSpeed)) km/h", weather.windDirection),
            ("Precipitation", "\(weather.precipitationChance)%", "Next hour",
             "UV index", "\(weather.uvIndex)", weather.uvDescription),
            ("Visibility", "\(Int(weather.visibility)) km", weather.visibilityDescription,
             "Pressure", "\(Int(weather.pressure)) hPa", weather.pressureTrend),
        ]

        return VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(alignment: .top, spacing: 0) {
                    MetricCell(title: row.0, value: row.1, subtitle: row.2)
                    Rectangle()
                        .fill(Color.white.opacity(0.10))
                        .frame(width: 1)
                    MetricCell(title: row.3, value: row.4, subtitle: row.5)
                }
                if rows.firstIndex(where: { $0.0 == row.0 }) != rows.count - 1 {
                    Rectangle()
                        .fill(Color.white.opacity(0.10))
                        .frame(height: 1)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppTheme.cardGlass)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.bottom, 20)
    }

    // MARK: UpThere Insight Section
    private var insightSection: some View {
        Group {
            if let rain = weather.rainWindow {
                Button {
                    onNavigateToInsights?()
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(AppTheme.textSecondary)
                            Text("UpThere insight")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                        Text(rain.title)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                        Text(rain.timeRange)
                            .font(.system(size: 28, weight: .thin, design: .rounded))
                            .foregroundStyle(AppTheme.textPrimary)
                            .tracking(-0.5)
                        Text(rain.detail)
                            .font(.system(size: 14))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }
                .buttonStyle(.plain)
                .padding(.bottom, 16)
            }
        }
    }

    // MARK: Precipitation Bar Chart
    private var precipitationChart: some View {
        Group {
            if !weather.hourlyForecast.isEmpty {
                PrecipitationBarChart(hourly: weather.hourlyForecast)
                    .frame(height: 64)
                    .padding(.bottom, 20)
            }
        }
    }

    // MARK: Temperature Line Chart
    private var temperatureChart: some View {
        Group {
            if !weather.hourlyForecast.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("How will temperature change?")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                        Text("Drag across the chart to see each hour.")
                            .font(.system(size: 13))
                            .foregroundStyle(AppTheme.textSecondary)
                    }

                    TemperatureLineChart(
                        hourly: weather.hourlyForecast,
                        high: weather.highTemperature,
                        low: weather.lowTemperature
                    )

                    Text(weather.warmingInsight)
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(AppTheme.cardGlass)
                )
                .padding(.bottom, 20)
            }
        }
    }

    // MARK: Today Section
    private var todaySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Today")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)

            let items: [(String, String, String, String)] = [
                ("High / Low", "\(Int(weather.highTemperature))°/\(Int(weather.lowTemperature))°",
                 "Chance of rain", "\(weather.chanceOfRain)%"),
                ("Sunrise", weather.sunrise, "Sunset", weather.sunset),
            ]

            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.offset) { idx, row in
                    HStack(spacing: 0) {
                        TodayCell(label: row.0, value: row.1)
                        Rectangle().fill(Color.white.opacity(0.10)).frame(width: 1)
                        TodayCell(label: row.2, value: row.3)
                    }
                    if idx < items.count - 1 {
                        Rectangle().fill(Color.white.opacity(0.10)).frame(height: 1)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AppTheme.cardGlass)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .padding(.bottom, 20)
    }
}

// MARK: - MetricCell

private struct MetricCell: View {
    let title: String
    let value: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.textSecondary)
            Text(value)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)
            Text(subtitle)
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
    }
}

// MARK: - TodayCell

private struct TodayCell: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.textSecondary)
            Text(value)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
    }
}

// MARK: - PrecipitationBarChart

private struct PrecipitationBarChart: View {
    let hourly: [HourlyWeather]

    private let highlightRange: ClosedRange<Double> = 0.50...1.0

    var body: some View {
        VStack(spacing: 8) {
            GeometryReader { geo in
                let barWidth: CGFloat = (geo.size.width - CGFloat(hourly.count - 1) * 3) / CGFloat(hourly.count)
                HStack(alignment: .bottom, spacing: 3) {
                    ForEach(hourly) { item in
                        let isHighlight = item.precipitationProbability >= 0.50
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(isHighlight ? Color.white.opacity(0.85) : Color.white.opacity(0.30))
                            .frame(
                                width: barWidth,
                                height: max(4, geo.size.height * item.precipitationProbability)
                            )
                    }
                }
                .frame(maxHeight: .infinity, alignment: .bottom)
            }

            // Time labels for key slots
            HStack {
                Text("8 AM").frame(maxWidth: .infinity, alignment: .leading)
                Text("12 PM").frame(maxWidth: .infinity, alignment: .center)
                Text("6 PM").frame(maxWidth: .infinity, alignment: .center)
                Text("11 PM").frame(maxWidth: .infinity, alignment: .trailing)
            }
            .font(.system(size: 11))
            .foregroundStyle(AppTheme.textSecondary)
        }
    }
}

// TemperatureLineChart lives in TemperatureLineChart.swift

// MARK: - Preview

private let _previewVM: HomeViewModel = {
    let repo = MockWeatherRepository()
    let uc = GetWeatherUseCase(repository: repo)
    return HomeViewModel(getWeatherUseCase: uc)
}()

#Preview {
    ZStack {
        AppTheme.backgroundGradient.ignoresSafeArea()
        HomeView(viewModel: _previewVM)
    }
}
