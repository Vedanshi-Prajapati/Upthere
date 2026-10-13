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
            WeatherBackgroundView(
                condition: viewModel.displayedWeather?.condition,
                symbolName: viewModel.displayedWeather?.weatherSymbolName
            )

            switch viewModel.state {
            case .idle:
                Color.clear.task { await viewModel.loadWeather() }

            case .loading(let isSilent):
                if !isSilent {
                    LoadingSkeletonView()
                } else if let weather = viewModel.displayedWeather {
                    WeatherScrollContent(
                        weather: weather,
                        banner: nil,
                        onNavigateToInsights: onNavigateToInsights
                    )
                    .refreshable {
                        await viewModel.refreshWeather()
                    }
                } else {
                    LoadingSkeletonView()
                }

            case .loaded(let weather, let banner):
                WeatherScrollContent(
                    weather: weather,
                    banner: banner,
                    onNavigateToInsights: onNavigateToInsights
                )
                .refreshable {
                    await viewModel.refreshWeather()
                }

            case .error:
                NetworkErrorView {
                    Task { await viewModel.loadWeather(force: true) }
                }
            }
        }
        .task { await viewModel.loadWeather() }
    }
}

// MARK: - WeatherScrollContent

private struct WeatherScrollContent: View {
    let weather: Weather
    let banner: HomeViewModel.BannerType?
    var onNavigateToInsights: (() -> Void)?

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                if let banner = banner {
                    bannerView(banner)
                }

                headerSection
                temperatureSection
                descriptionSection
                if let alert = weather.alert, !alert.isExpired {
                    alertSection(alert)
                }
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

    // MARK: Banner
    @ViewBuilder
    private func bannerView(_ banner: HomeViewModel.BannerType) -> some View {
        HStack(spacing: 8) {
            switch banner {
            case .cached(let time):
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 13, weight: .semibold))
                Text("Showing cached forecast from \(time)")
                    .font(.system(size: 13))
            case .offline(let time):
                Image(systemName: "wifi.slash")
                    .font(.system(size: 13, weight: .semibold))
                Text("Offline · Saved forecast from \(time)")
                    .font(.system(size: 13))
            case .refreshFailed(let reason):
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.alertAmber)
                Text("Could not refresh: \(reason)")
                    .font(.system(size: 13))
                    .lineLimit(1)
            case .locationFallback(let reason):
                Image(systemName: "location.slash.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(red: 0.6, green: 0.8, blue: 1.0))
                Text("Using default location (Ghaziabad) · \(reason)")
                    .font(.system(size: 13))
                    .lineLimit(1)
            }
            Spacer()
        }
        .foregroundStyle(AppTheme.textSecondary)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.12))
        )
        .padding(.bottom, 12)
        .accessibilityElement(children: .combine)
    }

    // MARK: Header
    private var headerSection: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    // Only show the location arrow when showing live GPS data (not a pinned city)
                    if weather.locationSubtitle.contains("GPS") ||
                       weather.locationSubtitle.isEmpty ||
                       weather.locationSubtitle.contains("Current") {
                        Image(systemName: "location.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                    }
                    Text(weather.cityName)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                }
                Text(weather.locationSubtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            Spacer()
        }
        .padding(.top, 8)
        .padding(.bottom, 12)
        .accessibilityElement(children: .combine)
    }

    // MARK: Hero Weather Display (Temperature & Prominent Illustration Graphic)
    private var temperatureSection: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(WeatherFormatter.shared.temp(weather.temperature))
                    .font(.system(size: 88, weight: .thin, design: .rounded))
                    .foregroundStyle(AppTheme.textPrimary)
                    .tracking(-2)
                    .accessibilityLabel(Text("\(WeatherFormatter.shared.tempWithUnit(weather.temperature))"))

                Text(weather.condition)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)

                let feelsLike = WeatherFormatter.shared.temp(weather.feelsLike)
                let high = WeatherFormatter.shared.temp(weather.highTemperature)
                let low = WeatherFormatter.shared.temp(weather.lowTemperature)
                Text("Feels like \(feelsLike) · H \(high) L \(low)")
                    .font(.system(size: 15))
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Spacer(minLength: 8)

            WeatherIllustrationView(
                condition: weather.condition,
                symbolName: weather.weatherSymbolName,
                size: 104,
                animated: true
            )
            .shadow(color: Color.black.opacity(0.18), radius: 14, x: 0, y: 8)
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
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens severe weather alert details")
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
        let dew = WeatherFormatter.shared.temp(weather.dewPoint)
        let wind = WeatherFormatter.shared.wind(weather.windSpeed)
        let vis = WeatherFormatter.shared.visibility(weather.visibility)
        let press = WeatherFormatter.shared.pressure(weather.pressure)

        let rows: [(String, String, String, String, String, String)] = [
            ("Humidity", "\(weather.humidity)%", "Dew point \(dew)",
             "Wind", wind, weather.windDirection),
            ("Precipitation", "\(weather.precipitationChance)%", "Next hour",
             "UV index", "\(weather.uvIndex)", weather.uvDescription),
            ("Visibility", vis, weather.visibilityDescription,
             "Pressure", press, weather.pressureTrend),
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
                .accessibilityElement(children: .combine)
            } else if weather.precipitationChance < 10 {
                // Dry day — show a clear summary instead of empty grey dashes
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .symbolRenderingMode(.multicolor)
                        .foregroundStyle(.white)
                        .font(.system(size: 20))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("No rain expected today")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                        Text("Enjoy the dry weather.")
                            .font(.system(size: 13))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }
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

                    if !weather.warmingInsight.isEmpty {
                        Text(weather.warmingInsight)
                            .font(.system(size: 13))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
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

            HStack(alignment: .top, spacing: 0) {
                TodayCell(label: "Chance of rain", value: "\(weather.chanceOfRain)%")
                Rectangle()
                    .fill(Color.white.opacity(0.10))
                    .frame(width: 1, height: 60)
                TodayCell(label: "Sunrise", value: weather.sunrise.isEmpty ? "6:00 AM" : weather.sunrise)
                Rectangle()
                    .fill(Color.white.opacity(0.10))
                    .frame(width: 1, height: 60)
                TodayCell(label: "Sunset", value: weather.sunset.isEmpty ? "6:00 PM" : weather.sunset)
            }
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AppTheme.cardGlass)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
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
        .accessibilityElement(children: .combine)
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
        .accessibilityElement(children: .combine)
    }
}

// MARK: - PrecipitationBarChart

private struct PrecipitationBarChart: View {
    let hourly: [HourlyWeather]

    var body: some View {
        VStack(spacing: 8) {
            GeometryReader { geo in
                let count = max(1, hourly.count)
                let barWidth: CGFloat = max(2, (geo.size.width - CGFloat(count - 1) * 3) / CGFloat(count))
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

            // Dynamic time labels for key slots
            if let first = hourly.first, let last = hourly.last {
                HStack {
                    Text(first.time).frame(maxWidth: .infinity, alignment: .leading)
                    if hourly.count > 4 {
                        Text(hourly[hourly.count / 3].time).frame(maxWidth: .infinity, alignment: .center)
                        Text(hourly[2 * hourly.count / 3].time).frame(maxWidth: .infinity, alignment: .center)
                    }
                    Text(last.time).frame(maxWidth: .infinity, alignment: .trailing)
                }
                .font(.system(size: 11))
                .foregroundStyle(AppTheme.textSecondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Precipitation probability over the next \(hourly.count) hours")
    }
}

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
