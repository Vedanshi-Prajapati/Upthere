import SwiftUI

// MARK: - HomeView

public struct HomeView: View {
    @State private var viewModel: HomeViewModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var hasAppeared = false
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

            if let weather = viewModel.displayedWeather {
                WeatherScrollContent(
                    weather: weather,
                    banner: bannerForState,
                    isCurrentLocation: viewModel.isCurrentLocation,
                    onNavigateToInsights: onNavigateToInsights
                )
                .refreshable {
                    await viewModel.refreshWeather()
                }
            } else {
                switch viewModel.state {
                case .idle, .loading:
                    LoadingSkeletonView()
                case .error:
                    NetworkErrorView {
                        Task { await viewModel.loadWeather(force: true) }
                    }
                case .loaded:
                    LoadingSkeletonView()
                }
            }
        }
        .task {
            if !hasAppeared {
                hasAppeared = true
                await viewModel.loadWeather()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                handleAppBecameActive()
            }
        }
    }

    private var bannerForState: HomeViewModel.BannerType? {
        if case .loaded(_, let banner) = viewModel.state {
            return banner
        }
        return nil
    }

    private func handleAppBecameActive() {
        guard let weather = viewModel.displayedWeather else {
            Task { await viewModel.loadWeather() }
            return
        }
        let age = Date().timeIntervalSince(weather.fetchTimestamp)
        if age > 600 {
            Task { await viewModel.refreshWeather() }
        } else {
            Task {
                await RainActivityManager.shared.updateOnForegroundRefresh(
                    hourly: weather.hourlyForecast,
                    city: weather.cityName
                )
            }
        }
    }
}

// MARK: - WeatherScrollContent

private struct WeatherScrollContent: View {
    let weather: Weather
    let banner: HomeViewModel.BannerType?
    let isCurrentLocation: Bool
    var onNavigateToInsights: (() -> Void)?

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                if let banner = banner {
                    bannerView(banner)
                }

                headerSection
                    .accessibilitySortPriority(10)
                temperatureSection
                    .accessibilitySortPriority(9)
                descriptionSection
                    .accessibilitySortPriority(8)
                if let alert = weather.alert, !alert.isExpired {
                    alertSection(alert)
                        .accessibilitySortPriority(7.5)
                }
                divider
                insightSection
                    .accessibilitySortPriority(7)
                temperatureChart
                    .accessibilitySortPriority(6)
                precipitationChart
                    .accessibilitySortPriority(5)
                metricsGrid
                    .accessibilitySortPriority(4)
                divider
                todaySection
                    .accessibilitySortPriority(3)
            }
            .padding(.horizontal, AppTheme.spacingXLarge)
            .padding(.top, AppTheme.spacingSmall)
            .padding(.bottom, AppTheme.tabBarClearance)
        }
    }

    // MARK: Banner
    @ViewBuilder
    private func bannerView(_ banner: HomeViewModel.BannerType) -> some View {
        HStack(spacing: AppTheme.spacingSmall) {
            switch banner {
            case .cached(let time):
                Image(systemName: "clock.arrow.circlepath")
                    .font(.footnote.weight(.semibold))
                Text("Showing cached forecast from \(time)")
                    .font(.footnote)
            case .offline(let time):
                Image(systemName: "wifi.slash")
                    .font(.footnote.weight(.semibold))
                Text("Offline · Saved forecast from \(time)")
                    .font(.footnote)
            case .refreshFailed(let reason):
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppTheme.alertAmber)
                Text("Could not refresh: \(reason)")
                    .font(AppFont.footnote)
            case .locationFallback(let reason):
                Image(systemName: "location.slash.fill")
                    .font(AppFont.footnoteSemibold)
                    .foregroundStyle(Color(red: 0.6, green: 0.8, blue: 1.0))
                Text("Using default location (Ghaziabad) · \(reason)")
                    .font(AppFont.footnote)
            }
            Spacer()
        }
        .foregroundStyle(AppTheme.textSecondary)
        .padding(.horizontal, 14)
        .padding(.vertical, AppTheme.spacingSmall)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.radiusSmall, style: .continuous)
                .fill(Color.white.opacity(0.12))
        )
        .padding(.bottom, AppTheme.spacingMedium)
        .accessibilityElement(children: .combine)
    }

    // MARK: Header
    private var headerSection: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    if isCurrentLocation {
                        Image(systemName: "location.fill")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                    }
                    Text(weather.cityName)
                        .font(.headline)
                        .foregroundStyle(AppTheme.textPrimary)
                }
                Text(weather.locationSubtitle)
                    .font(.footnote)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            Spacer()
        }
        .padding(.top, AppTheme.spacingSmall)
        .padding(.bottom, AppTheme.spacingMedium)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(weather.cityName), \(weather.locationSubtitle)")
    }

    // MARK: Hero Weather Display (Temperature & Prominent Illustration Graphic)
    private var temperatureSection: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: AppTheme.spacingMedium) {
                    heroTextContent
                    heroIllustration
                }
            } else {
                HStack(alignment: .center, spacing: 14) {
                    heroTextContent
                    Spacer(minLength: 8)
                    heroIllustration
                }
            }
        }
        .padding(.bottom, AppTheme.spacingLarge)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(weather.condition), \(WeatherFormatter.shared.tempWithUnit(weather.temperature)), Feels like \(WeatherFormatter.shared.temp(weather.feelsLike)), High \(WeatherFormatter.shared.temp(weather.highTemperature)), Low \(WeatherFormatter.shared.temp(weather.lowTemperature))")
    }

    private var heroTextContent: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingXXSmall) {
            ScaledHeroTemperature(weather.temperature)

            Text(weather.condition)
                .font(AppFont.title2Bold)
                .foregroundStyle(AppTheme.textPrimary)

            let feelsLike = WeatherFormatter.shared.temp(weather.feelsLike)
            let high = WeatherFormatter.shared.temp(weather.highTemperature)
            let low = WeatherFormatter.shared.temp(weather.lowTemperature)
            Text("Feels like \(feelsLike) · H \(high) L \(low)")
                .font(AppFont.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
        }
    }

    private var heroIllustration: some View {
        WeatherIllustrationView(
            condition: weather.condition,
            symbolName: weather.weatherSymbolName,
            size: 76,
            animated: true
        )
        .shadow(color: Color.black.opacity(0.10), radius: 8, x: 0, y: 4)
    }

    // MARK: Description
    private var descriptionSection: some View {
        Text(weather.description)
            .font(.subheadline)
            .foregroundStyle(AppTheme.textSecondary)
            .lineSpacing(4)
            .padding(.bottom, AppTheme.spacingXLarge)
    }

    // MARK: Alert
    private func alertSection(_ alert: WeatherAlert) -> some View {
        Button {
            onNavigateToInsights?()
        } label: {
            WeatherCard(padding: AppTheme.spacingLarge, borderColor: AppTheme.alertAmber.opacity(0.6)) {
                HStack(alignment: .top, spacing: AppTheme.spacingMedium) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(AppTheme.alertAmber)
                        .font(.headline)
                        .padding(.top, 2)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Official alert · \(alert.source)")
                            .font(.footnote)
                            .foregroundStyle(AppTheme.alertAmber)
                        Text(alert.title)
                            .font(.headline)
                            .foregroundStyle(AppTheme.textPrimary)
                        Text(alert.validUntil)
                            .font(.footnote)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(AppTheme.textTertiary)
                        .font(.subheadline.weight(.medium))
                        .padding(.top, 2)
                }
            }
        }
        .buttonStyle(.plain)
        .padding(.bottom, AppTheme.spacingXLarge)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens severe weather alert details")
    }

    // MARK: Divider
    private var divider: some View {
        Rectangle()
            .fill(AppTheme.separator)
            .frame(height: 1)
            .padding(.bottom, AppTheme.spacingXLarge)
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

        return WeatherCard(padding: EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)) {
            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    if dynamicTypeSize.isAccessibilitySize {
                        VStack(alignment: .leading, spacing: 0) {
                            MetricCell(title: row.0, value: row.1, subtitle: row.2)
                            Rectangle().fill(AppTheme.cardBorderLight).frame(height: 1)
                            MetricCell(title: row.3, value: row.4, subtitle: row.5)
                        }
                    } else {
                        HStack(alignment: .top, spacing: 0) {
                            MetricCell(title: row.0, value: row.1, subtitle: row.2)
                            Rectangle()
                                .fill(AppTheme.cardBorderLight)
                                .frame(width: 1)
                            MetricCell(title: row.3, value: row.4, subtitle: row.5)
                        }
                    }
                    if rows.firstIndex(where: { $0.0 == row.0 }) != rows.count - 1 {
                        Rectangle()
                            .fill(AppTheme.cardBorderLight)
                            .frame(height: 1)
                    }
                }
            }
        }
        .padding(.bottom, AppTheme.spacingXLarge)
    }

    // MARK: UpThere Insight Section
    private var rainInsight: (title: String, timeRange: String, detail: String)? {
        guard let rain = InsightEngine().rainWindow(from: weather.hourlyForecast) else {
            return nil
        }
        let timeFormatter = DateFormatter()
        timeFormatter.locale = Locale(identifier: "en_US")
        timeFormatter.dateFormat = "ha"

        let startStr = timeFormatter.string(from: rain.startDate)
        let endStr = timeFormatter.string(from: rain.endDate)
        let timeRange = startStr == endStr ? "Around \(startStr)" : "\(startStr) – \(endStr)"

        let peakStr = timeFormatter.string(from: rain.peakDate)
        let peakPercent = Int((rain.peakProbability * 100).rounded())
        let detail = "Peak precipitation around \(peakStr), \(peakPercent)% probability."

        let title: String
        if rain.peakProbability >= 0.70 {
            title = "Heavy rain expected"
        } else if rain.peakProbability >= 0.50 {
            title = "Rain expected"
        } else {
            title = "Showers likely"
        }

        return (title, timeRange, detail)
    }

    private var insightSection: some View {
        Group {
            if let rain = rainInsight {
                VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
                    Button {
                        onNavigateToInsights?()
                    } label: {
                        VStack(alignment: .leading, spacing: AppTheme.spacingXSmall) {
                            HStack(spacing: AppTheme.spacingXSmall) {
                                Image(systemName: "sparkles")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(AppTheme.textSecondary)
                                Text("UpThere insight")
                                    .font(.footnote.weight(.medium))
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                            Text(rain.title)
                                .font(.headline)
                                .foregroundStyle(AppTheme.textPrimary)
                            Text(rain.timeRange)
                                .font(.title.weight(.light))
                                .foregroundStyle(AppTheme.textPrimary)
                                .tracking(-0.5)
                            Text(rain.detail)
                                .font(.footnote)
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .combine)

                    if let window = InsightEngine().rainWindow(from: weather.hourlyForecast),
                       RainActivityStateCalculator.isRainWithinTwoHours(rainWindow: window) {
                        TrackRainButton(
                            cityName: weather.cityName,
                            hourly: weather.hourlyForecast
                        )
                    }
                }
                .padding(.bottom, AppTheme.spacingLarge)
            } else if weather.precipitationChance < 10 {
                // Dry day — show a clear summary instead of empty grey dashes
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .symbolRenderingMode(.multicolor)
                        .symbolVariant(.fill)
                        .foregroundStyle(.white)
                        .font(.title3)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("No rain expected today")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                        Text("Enjoy the dry weather.")
                            .font(.footnote)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }
                .padding(.bottom, AppTheme.spacingLarge)
                .accessibilityElement(children: .combine)
            }
        }
    }

    // MARK: Precipitation Bar Chart
    private var precipitationChart: some View {
        Group {
            if !weather.hourlyForecast.isEmpty {
                WeatherCard(padding: AppTheme.spacingLarge) {
                    VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
                        Text("Precipitation probability")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                        PrecipitationBarChart(hourly: weather.hourlyForecast)
                            .frame(height: 64)
                    }
                }
                .padding(.bottom, AppTheme.spacingXLarge)
            }
        }
    }

    // MARK: Temperature Line Chart
    private var temperatureChart: some View {
        Group {
            if !weather.hourlyForecast.isEmpty {
                WeatherCard(padding: AppTheme.spacingLarge) {
                    VStack(alignment: .leading, spacing: AppTheme.spacingMedium) {
                        VStack(alignment: .leading, spacing: AppTheme.spacingXXSmall) {
                            Text("How will temperature change?")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.textPrimary)
                            Text("Drag across the chart to see each hour.")
                                .font(.footnote)
                                .foregroundStyle(AppTheme.textSecondary)
                        }

                        TemperatureLineChart(
                            hourly: weather.hourlyForecast,
                            high: weather.highTemperature,
                            low: weather.lowTemperature
                        )

                        let warmingText: String = {
                            if let trend = InsightEngine().temperatureTrend(from: weather.hourlyForecast) {
                                let f = DateFormatter()
                                f.locale = Locale(identifier: "en_US")
                                f.dateFormat = "ha"
                                let minH = f.string(from: trend.minDate).lowercased()
                                let maxH = f.string(from: trend.maxDate).lowercased()
                                let swing = Int(trend.temperatureSwing.rounded())
                                return "+\(swing)° temperature change from \(minH) to \(maxH)"
                            }
                            return weather.warmingInsight
                        }()
                        if !warmingText.isEmpty {
                            Text(warmingText)
                                .font(.footnote)
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                    }
                }
                .padding(.bottom, AppTheme.spacingXLarge)
            }
        }
    }

    // MARK: Today Section
    private var todaySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Today")
                .font(AppFont.headline)
                .foregroundStyle(AppTheme.textPrimary)

            WeatherCard(padding: EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)) {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 0) {
                        TodayCell(label: "Chance of rain", value: "\(weather.chanceOfRain)%")
                        Rectangle().fill(AppTheme.cardBorderLight).frame(height: 1)
                        TodayCell(label: "Sunrise", value: weather.sunrise.isEmpty ? "6:00 AM" : weather.sunrise)
                        Rectangle().fill(AppTheme.cardBorderLight).frame(height: 1)
                        TodayCell(label: "Sunset", value: weather.sunset.isEmpty ? "6:00 PM" : weather.sunset)
                    }
                } else {
                    HStack(alignment: .top, spacing: 0) {
                        TodayCell(label: "Chance of rain", value: "\(weather.chanceOfRain)%")
                        Rectangle()
                            .fill(AppTheme.cardBorderLight)
                            .frame(width: 1)
                        TodayCell(label: "Sunrise", value: weather.sunrise.isEmpty ? "6:00 AM" : weather.sunrise)
                        Rectangle()
                            .fill(AppTheme.cardBorderLight)
                            .frame(width: 1)
                        TodayCell(label: "Sunset", value: weather.sunset.isEmpty ? "6:00 PM" : weather.sunset)
                    }
                }
            }
        }
    }
}

// MARK: - MetricCell

private struct MetricCell: View {
    let title: String
    let value: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingXXSmall) {
            Text(title)
                .font(.footnote)
                .foregroundStyle(AppTheme.textSecondary)
            Text(value)
                .font(.title2.weight(.semibold))
                .foregroundStyle(AppTheme.textPrimary)
            Text(subtitle)
                .font(.footnote)
                .foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 14)
        .padding(.horizontal, AppTheme.spacingLarge)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - TodayCell

private struct TodayCell: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingXXSmall) {
            Text(label)
                .font(.footnote)
                .foregroundStyle(AppTheme.textSecondary)
            Text(value)
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 14)
        .padding(.horizontal, AppTheme.spacingLarge)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - PrecipitationBarChart

private struct PrecipitationBarChart: View {
    let hourly: [HourlyWeather]

    private var summary: String {
        let maxPrecip = Int(round((hourly.map(\.precipitationProbability).max() ?? 0) * 100))
        let peakHour = hourly.max(by: { $0.precipitationProbability < $1.precipitationProbability })
        if maxPrecip >= 10, let peakHour = peakHour {
            return "Peak chance of \(maxPrecip)% around \(peakHour.time)"
        } else {
            return "No precipitation expected in the next \(hourly.count) hours"
        }
    }

    var body: some View {
        VStack(spacing: AppTheme.spacingSmall) {
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
                .font(.caption2)
                .foregroundStyle(AppTheme.textSecondary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Precipitation probability chart")
        .accessibilityValue(summary)
    }
}

// MARK: - Preview

private let _previewVM: HomeViewModel = {
    let repo = MockWeatherRepository()
    let uc = GetWeatherUseCase(repository: repo)
    return HomeViewModel(getWeatherUseCase: uc)
}()

#Preview("Home") {
    ZStack {
        AppTheme.backgroundGradient.ignoresSafeArea()
        HomeView(viewModel: _previewVM)
    }
}

#Preview("Home AX3") {
    ZStack {
        AppTheme.backgroundGradient.ignoresSafeArea()
        HomeView(viewModel: _previewVM)
    }
    .dynamicTypeSize(.accessibility3)
}
