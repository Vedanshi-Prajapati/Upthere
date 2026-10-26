import SwiftUI

// MARK: - HomeView

struct HomeView: View {
    @State private var viewModel: HomeViewModel
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.isHomeTabSelected) private var isHomeTabSelected
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hasAppeared = false
    var onNavigateToInsights: (() -> Void)?

    init(viewModel: HomeViewModel, onNavigateToInsights: (() -> Void)? = nil) {
        self._viewModel = State(initialValue: viewModel)
        self.onNavigateToInsights = onNavigateToInsights
    }

    private var animationManager = WeatherAnimationManager.shared

    private var isAnimationPaused: Bool {
        animationManager.shouldPause(
            scenePhase: scenePhase,
            isHomeTab: isHomeTabSelected,
            reduceMotion: reduceMotion
        )
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: isAnimationPaused)) { timeline in
            let clockTime = isAnimationPaused ? 0.0 : timeline.date.timeIntervalSinceReferenceDate
            homeContent
                .environment(\.weatherClockTime, clockTime)
                .environment(\.weatherParticleScale, animationManager.particleScale)
                .environment(\.isWeatherAnimationPaused, isAnimationPaused)
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

    private var homeContent: some View {
        ZStack {
            if let weather = viewModel.displayedWeather {
                WeatherScrollContent(
                    weather: weather,
                    banner: bannerForState,
                    isCurrentLocation: viewModel.isCurrentLocation,
                    onNavigateToInsights: onNavigateToInsights,
                    onRetry: {
                        Task {
                            await viewModel.retryLocation()
                        }
                    },
                    onOpenSettings: {
                        viewModel.openSettings()
                    }
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
    var onRetry: (() -> Void)? = nil
    var onOpenSettings: (() -> Void)? = nil

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.weatherFormatter) private var weatherFormatter

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
                AttributionView()
                    .padding(.top, AppTheme.spacingLarge)
                    .accessibilitySortPriority(2)
            }
            .padding(.horizontal, AppTheme.spacingXLarge)
            .padding(.top, AppTheme.spacingSmall)
        }
        .scrollEdgeEffectStyle(.soft, for: .top)
        .scrollEdgeEffectStyle(.soft, for: .bottom)
        .contentMargins(.bottom, AppTheme.tabBarClearance, for: .scrollContent)
    }

    // MARK: Banner
    @ViewBuilder
    private func bannerView(_ banner: HomeViewModel.BannerType) -> some View {
        HStack(spacing: AppTheme.spacingSmall) {
            switch banner {
            case .cached(let time):
                Image(systemName: "clock.arrow.circlepath")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                Text("Showing cached forecast from \(time)")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.textSecondary)
            case .offline(let time):
                Image(systemName: "wifi.slash")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                Text("Offline · Saved forecast from \(time)")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.textSecondary)
            case .refreshFailed(let reason):
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppTheme.alertAmber)
                Text("Could not refresh: \(reason)")
                    .font(AppFont.footnote)
                    .foregroundStyle(AppTheme.textPrimary)
            case .locationFallback(let message, _):
                Image(systemName: "location.slash.fill")
                    .font(AppFont.footnoteSemibold)
                    .foregroundStyle(AppTheme.accent)
                Text(message)
                    .font(AppFont.footnote)
                    .foregroundStyle(AppTheme.textPrimary)
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
        .contentShape(Rectangle())
        .onTapGesture {
            if case .locationFallback(_, let action) = banner {
                switch action {
                case .openSettings:
                    if let onOpenSettings = onOpenSettings {
                        onOpenSettings()
                    } else if let url = URL(string: UIApplication.openSettingsURLString),
                              UIApplication.shared.canOpenURL(url) {
                        UIApplication.shared.open(url)
                    }
                case .retry:
                    onRetry?()
                case nil:
                    break
                }
            }
        }
        .padding(.bottom, AppTheme.spacingMedium)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("home_banner_action")
        .accessibilitySortPriority(11)
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
                        .accessibilityAddTraits(.isHeader)
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
        .accessibilityLabel(
            "\(weather.condition), \(weatherFormatter.tempWithUnit(weather.temperature)), " +
            "Feels like \(weatherFormatter.temp(weather.feelsLike)), " +
            "High \(weatherFormatter.temp(weather.highTemperature)), " +
            "Low \(weatherFormatter.temp(weather.lowTemperature))"
        )
        .accessibilityIdentifier("hero_section")
    }

    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    private var heroTextContent: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingXXSmall) {
            ScaledHeroTemperature(weather.temperature)
                .accessibilityIdentifier("hero_temperature")

            Text(weather.condition)
                .font(AppFont.title2Bold)
                .foregroundStyle(AppTheme.textPrimary)

            let feelsLike = weatherFormatter.temp(weather.feelsLike)
            let high = weatherFormatter.temp(weather.highTemperature)
            let low = weatherFormatter.temp(weather.lowTemperature)
            Text("Feels like \(feelsLike) · Today H/L \(high) \(low)")
                .font(AppFont.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
        }
        .accessibilityIdentifier("hero_text_content")
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.radiusMedium, style: .continuous)
                .fill(Color.black.opacity(0.18))
                .blur(radius: 6)
        )
    }

    private var heroIllustration: some View {
        WeatherIllustrationView(
            condition: weather.condition,
            symbolName: weather.weatherSymbolName,
            size: 76,
            animated: true
        )
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
                        HStack(spacing: 4) {
                            if differentiateWithoutColor {
                                Text("[ALERT]")
                                    .font(AppFont.captionSemibold)
                                    .foregroundStyle(AppTheme.alertAmber)
                            }
                            Text("Official alert · \(alert.source)")
                                .font(.footnote)
                                .foregroundStyle(AppTheme.alertAmber)
                        }
                        Text(alert.title)
                            .font(.headline)
                            .foregroundStyle(AppTheme.textPrimary)
                            .accessibilityAddTraits(.isHeader)
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
        .accessibilityIdentifier("home_alert_button")
        .accessibilityLabel("Severe weather alert: \(alert.title). \(alert.validUntil)")
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
        let dew = weatherFormatter.temp(weather.dewPoint)
        let wind = weatherFormatter.wind(weather.windSpeed)
        let vis = weatherFormatter.visibility(weather.visibility)
        let press = weatherFormatter.pressure(weather.pressure)

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
                                    .accessibilityAddTraits(.isHeader)
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
                    .accessibilityIdentifier("home_insight_button")
                    .accessibilityLabel("UpThere insight: \(rain.title), \(rain.timeRange). \(rain.detail)")
                    .accessibilityHint("Opens Insights tab")

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
                        .foregroundStyle(AppTheme.textPrimary)
                        .font(.title3)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("No rain expected today")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                            .accessibilityAddTraits(.isHeader)
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
                            .accessibilityAddTraits(.isHeader)

                        let maxPrecip = weather.hourlyForecast.prefix(24).map(\.precipitationProbability).max() ?? 0
                        if maxPrecip < 0.05 {
                            HStack(spacing: AppTheme.spacingSmall) {
                                Image(systemName: "sun.max.fill")
                                    .foregroundStyle(AppTheme.alertAmber)
                                Text("No rain expected in the next 24 hours")
                                    .font(.footnote)
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .frame(height: 44)
                        } else {
                            PrecipitationBarChart(hourly: weather.hourlyForecast)
                                .frame(height: 64)
                                .accessibilityIdentifier("home_precipitation_chart")
                        }
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
                                .accessibilityAddTraits(.isHeader)
                            Text("Drag across the chart to see each hour.")
                                .font(.footnote)
                                .foregroundStyle(AppTheme.textSecondary)
                        }

                        TemperatureLineChart(
                            hourly: weather.hourlyForecast,
                            currentTemperature: weather.temperature,
                            high: weather.highTemperature,
                            low: weather.lowTemperature
                        )
                        .accessibilityIdentifier("temperature_line_chart")

                        let warmingText: String = {
                            if let minHour = weather.hourlyForecast.min(by: { $0.temperature < $1.temperature }),
                               let maxHour = weather.hourlyForecast.max(by: { $0.temperature < $1.temperature }),
                               weather.hourlyForecast.count >= 2 {
                                let earlier = minHour.date <= maxHour.date ? minHour : maxHour
                                let later = minHour.date <= maxHour.date ? maxHour : minHour
                                let diff = Int(round(later.temperature - earlier.temperature))
                                if abs(diff) >= 1 {
                                    let f = DateFormatter()
                                    f.locale = Locale(identifier: "en_US")
                                    f.dateFormat = "ha"
                                    let startH = f.string(from: earlier.date).lowercased()
                                    let endH = f.string(from: later.date).lowercased()
                                    let sign = diff > 0 ? "+" : ""
                                    return "\(sign)\(diff)° change from \(startH) to \(endH)"
                                }
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
                .accessibilityAddTraits(.isHeader)

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
                    Text(first.time)
                        .foregroundStyle(AppTheme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if hourly.count > 4 {
                        Text(hourly[hourly.count / 3].time)
                            .foregroundStyle(AppTheme.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                        Text(hourly[2 * hourly.count / 3].time)
                            .foregroundStyle(AppTheme.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    Text(last.time)
                        .foregroundStyle(AppTheme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
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

#if DEBUG
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
#endif
