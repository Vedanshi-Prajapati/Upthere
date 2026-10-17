import SwiftUI

public struct ForecastView: View {
    @State private var viewModel: HomeViewModel
    @State private var selectedTab: ForecastTab = .daily
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.weatherFormatter) private var weatherFormatter

    public enum ForecastTab {
        case hourly, daily
    }

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
                forecastContent(weather: weather)
            } else {
                switch viewModel.state {
                case .idle:
                    Color.clear.task { await viewModel.loadWeather() }
                case .loading:
                    ProgressView().tint(.white)
                case .error(let msg, _):
                    Text(msg).foregroundStyle(AppTheme.textSecondary)
                        .padding(.horizontal, 24)
                case .loaded:
                    ProgressView().tint(.white)
                }
            }
        }
    }

    private func forecastContent(weather: Weather) -> some View {
        VStack(spacing: 0) {
            header(weather: weather)
            picker

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 24) {
                    if selectedTab == .daily {
                        dailyView(weather: weather)
                        PrecipitationSection(weather: weather, tab: .daily)
                            .padding(.horizontal, 20)
                    } else {
                        hourlyView(weather: weather)
                        PrecipitationSection(weather: weather, tab: .hourly)
                            .padding(.horizontal, 20)
                    }
                }
                .padding(.bottom, AppTheme.tabBarClearance)
            }
            .padding(.top, 16)
        }
    }

    private func header(weather: Weather) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Forecast")
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(.white)
            Text(weather.cityName)
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 20)
    }

    private var picker: some View {
        GlassEffectContainer(spacing: 2) {
            pickerButton(title: "Hourly", tab: .hourly)
            pickerButton(title: "Daily", tab: .daily)
        }
        .padding(.horizontal, 20)
    }

    private func pickerButton(title: String, tab: ForecastTab) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedTab = tab
            }
        } label: {
            Text(title)
                .font(.subheadline.weight(selectedTab == tab ? .semibold : .medium))
                .foregroundStyle(selectedTab == tab ? Color.white : AppTheme.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background(
                    Group {
                        if selectedTab == tab {
                            Capsule().fill(Color.white.opacity(0.18))
                        } else {
                            Color.clear
                        }
                    }
                )
        }
        .buttonStyle(.plain)
    }

    private func dailyView(weather: Weather) -> some View {
        let lows = weather.dailyForecast.map(\.lowTemperature)
        let highs = weather.dailyForecast.map(\.highTemperature)
        let overallMin = lows.min() ?? 10.0
        let overallMax = highs.max() ?? 35.0

        return WeatherCard(padding: EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0)) {
            VStack(spacing: 0) {
                ForEach(Array(weather.dailyForecast.enumerated()), id: \.offset) { index, daily in
                    DailyWeatherRow(
                        daily: daily,
                        overallMin: overallMin,
                        overallMax: overallMax
                    )
                    if index < weather.dailyForecast.count - 1 {
                        Rectangle()
                            .fill(Color.white.opacity(0.1))
                            .frame(height: 1)
                            .padding(.horizontal, 16)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
    }

    private func hourlyView(weather: Weather) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(weather.hourlyForecast) { hourly in
                        HourlyCard(hourly: hourly)
                    }
                }
                .padding(.horizontal, 20)
            }

            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Now")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.white)
                    Spacer()
                    Text(weather.condition)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .padding(.horizontal, 20)

                let currentT = weatherFormatter.temp(weather.temperature)
                let feelsT = weatherFormatter.temp(weather.feelsLike)
                let currentPrecipAmount = weather.hourlyForecast.first?.precipitationAmount ?? 0.0
                let precipVal = weatherFormatter.precipitation(currentPrecipAmount)

                let rows: [(String, String, String, String, String, String)] = [
                    ("Temperature", currentT, "Feels like \(feelsT)",
                     "Precipitation", "\(weather.precipitationChance)%", precipVal),
                    ("Wind", weatherFormatter.wind(weather.windSpeed), weather.windDirection,
                     "UV Index", "\(weather.uvIndex)", weather.uvDescription),
                    ("Humidity", "\(weather.humidity)%", "Dew point \(weatherFormatter.temp(weather.dewPoint))",
                     "Visibility", weatherFormatter.visibility(weather.visibility), weather.visibilityDescription),
                ]

                WeatherCard(padding: EdgeInsets()) {
                    VStack(spacing: 0) {
                        ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                            if dynamicTypeSize.isAccessibilitySize {
                                VStack(alignment: .leading, spacing: 0) {
                                    forecastMetricCell(title: row.0, value: row.1, subtitle: row.2)
                                    Rectangle().fill(AppTheme.separator).frame(height: 0.8)
                                    forecastMetricCell(title: row.3, value: row.4, subtitle: row.5)
                                }
                            } else {
                                HStack(alignment: .top, spacing: 0) {
                                    forecastMetricCell(title: row.0, value: row.1, subtitle: row.2)
                                    Rectangle().fill(AppTheme.separator).frame(width: 0.8)
                                    forecastMetricCell(title: row.3, value: row.4, subtitle: row.5)
                                }
                            }
                            if rows.firstIndex(where: { $0.0 == row.0 }) != rows.count - 1 {
                                Rectangle().fill(AppTheme.separator).frame(height: 0.8)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    private func forecastMetricCell(title: String, value: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(AppFont.captionMedium)
                .foregroundStyle(AppTheme.textSecondary)
            Text(value)
                .font(AppFont.title3)
                .foregroundStyle(AppTheme.textPrimary)
            Text(subtitle)
                .font(AppFont.caption)
                .foregroundStyle(AppTheme.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Precipitation Section

private struct PrecipitationSection: View {
    let weather: Weather
    var tab: ForecastView.ForecastTab = .daily

    private let rainBlue = Color(red: 0.35, green: 0.65, blue: 1.0)

    private var activeRainWindow: RainWindow? {
        if let rain = weather.rainWindow {
            return rain
        }
        if let result = InsightEngine().rainWindow(from: weather.hourlyForecast) {
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_US")
            f.dateFormat = "ha"
            let startH = f.string(from: result.startDate).lowercased()
            let endH = f.string(from: result.endDate).lowercased()
            let peakH = f.string(from: result.peakDate).lowercased()
            let peakProb = Int((result.peakProbability * 100).rounded())
            return RainWindow(
                title: "Rain Expected",
                timeRange: "\(startH) – \(endH)",
                detail: "Peak precipitation around \(peakH), \(peakProb)% probability."
            )
        }
        return nil
    }

    private var headerTrailingText: String {
        if tab == .hourly {
            let maxHourly = weather.hourlyForecast.prefix(24).map(\.precipitationProbability).max() ?? 0.0
            let peakPct = Int(round(maxHourly * 100))
            if peakPct > 0 {
                return "\(peakPct)% peak"
            } else {
                return "\(weather.chanceOfRain)% today"
            }
        } else {
            return "\(weather.chanceOfRain)% today"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section header
            HStack(spacing: 8) {
                Image(systemName: "drop.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(rainBlue)
                Text("Precipitation")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                Spacer()
                Text(headerTrailingText)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(rainBlue)
            }

            // Bar chart card
            WeatherCard(padding: EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)) {
                VStack(alignment: .leading, spacing: 14) {
                    Text(tab == .hourly ? "Hourly chance of rain" : "Daily chance of rain")
                        .font(.footnote)
                        .foregroundStyle(AppTheme.textSecondary)

                    if tab == .hourly {
                        if weather.hourlyForecast.isEmpty {
                            Text("No hourly forecast available")
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.textTertiary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 20)
                        } else {
                            HourlyPrecipitationBarChart(hourly: weather.hourlyForecast, rainBlue: rainBlue)
                        }
                    } else {
                        if weather.dailyForecast.isEmpty {
                            Text("No forecast data available")
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.textTertiary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 20)
                        } else {
                            PrecipitationBarChart(days: weather.dailyForecast, rainBlue: rainBlue)
                        }
                    }
                }
            }

            // Rain window card (if active)
            if let rain = activeRainWindow {
                RainWindowCard(rain: rain, rainBlue: rainBlue)
            }
        }
    }
}

// MARK: - Hourly Precipitation Bar Chart

private struct HourlyPrecipitationBarChart: View {
    let hourly: [HourlyWeather]
    let rainBlue: Color

    @Environment(\.weatherFormatter) private var weatherFormatter
    @State private var selectedIndex: Int?
    @State private var isDragging = false
    @State private var appeared = false

    private var items: [HourlyWeather] {
        Array(hourly.prefix(24))
    }

    private var chartSummary: String {
        guard !items.isEmpty else { return "No hourly precipitation data" }
        let peakHour = items.max(by: { $0.precipitationProbability < $1.precipitationProbability })
        let peakPct = Int(round((peakHour?.precipitationProbability ?? 0) * 100))
        if peakPct > 0, let peakHour {
            return "Peak precipitation probability of \(peakPct)% at \(peakHour.time) over \(items.count) hours"
        } else {
            return "No precipitation expected over the next \(items.count) hours"
        }
    }

    var body: some View {
        VStack(spacing: 10) {
            // Readout / indicator
            HStack {
                if let selectedIndex, items.indices.contains(selectedIndex) {
                    let item = items[selectedIndex]
                    let pct = Int(round(item.precipitationProbability * 100))
                    let precipAmount = weatherFormatter.precipitation(item.precipitationAmount)
                    HStack(spacing: 6) {
                        Text(item.time)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.white)
                        Text("•")
                            .foregroundStyle(AppTheme.textTertiary)
                        Text("\(pct)% chance")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(rainBlue)
                        if item.precipitationAmount > 0 {
                            Text("(\(precipAmount))")
                                .font(.caption)
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                    }
                } else {
                    let peakHour = items.max(by: { $0.precipitationProbability < $1.precipitationProbability })
                    let peakPct = Int(round((peakHour?.precipitationProbability ?? 0) * 100))
                    if peakPct > 0, let peakHour {
                        Text("Peak: \(peakHour.time) (\(peakPct)%)")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(rainBlue)
                    } else {
                        Text("No rain expected")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }
                Spacer()
                Text("Drag across hours")
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textTertiary)
            }
            .frame(height: 18)

            // Bars area
            GeometryReader { geo in
                let count = max(1, items.count)
                let spacing: CGFloat = 3
                let totalSpacing = CGFloat(count - 1) * spacing
                let barWidth = max(4, (geo.size.width - totalSpacing) / CGFloat(count))

                ZStack(alignment: .bottomLeading) {
                    HStack(alignment: .bottom, spacing: spacing) {
                        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                            let pct = item.precipitationProbability
                            let isSelected = selectedIndex == index

                            VStack(spacing: 0) {
                                Spacer()
                                RoundedRectangle(cornerRadius: 3, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: isSelected
                                                ? [Color.white, rainBlue]
                                                : (pct > 0.05
                                                    ? [rainBlue.opacity(0.95), rainBlue.opacity(0.4)]
                                                    : [Color.white.opacity(0.10)]),
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .frame(
                                        width: barWidth,
                                        height: appeared ? max(4, pct * geo.size.height) : 4
                                    )
                                    .overlay(
                                        Group {
                                            if isSelected {
                                                RoundedRectangle(cornerRadius: 3, style: .continuous)
                                                    .stroke(Color.white, lineWidth: 1)
                                            }
                                        }
                                    )
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                        }
                    }
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            guard !items.isEmpty else { return }
                            let rawFraction = value.location.x / geo.size.width
                            let clamped = max(0, min(1, rawFraction))
                            let newIndex = min(items.count - 1, max(0, Int(round(clamped * CGFloat(items.count - 1)))))
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
            .frame(height: 85)
            .onAppear {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    appeared = true
                }
            }

            // Time markers along bottom
            timeLabels
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Hourly precipitation timeline")
        .accessibilityValue(chartSummary)
    }

    private var timeLabels: some View {
        HStack {
            if let first = items.first {
                Text(first.time)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if items.count > 6 {
                let q1 = items[items.count / 4]
                Text(q1.time)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            if items.count > 2 {
                let mid = items[items.count / 2]
                Text(mid.time)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            if items.count > 6 {
                let q3 = items[3 * items.count / 4]
                Text(q3.time)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            if let last = items.last, items.count > 1 {
                Text(last.time)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .font(.caption2)
        .foregroundStyle(AppTheme.textSecondary)
    }
}

// MARK: - Precipitation Bar Chart

private struct PrecipitationBarChart: View {
    let days: [DailyWeather]
    let rainBlue: Color

    private var chartSummary: String {
        guard !days.isEmpty else { return "No precipitation data available" }
        let peakDay = days.max(by: { $0.precipitationProbability < $1.precipitationProbability })
        let peakPct = Int(round((peakDay?.precipitationProbability ?? 0) * 100))
        if peakPct > 0, let peakDay {
            return "7-day precipitation forecast. Highest chance is \(peakPct)% on \(peakDay.dayName)."
        } else {
            return "7-day precipitation forecast. No rain expected this week."
        }
    }

    var body: some View {
        GeometryReader { geo in
            let barWidth = max(8, (geo.size.width - CGFloat(days.count - 1) * 8) / CGFloat(days.count))
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(days) { day in
                    PrecipBar(
                        day: day,
                        barWidth: barWidth,
                        rainBlue: rainBlue
                    )
                }
            }
        }
        .frame(height: 120)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Precipitation forecast by day")
        .accessibilityValue(chartSummary)
    }
}

private struct PrecipBar: View {
    let day: DailyWeather
    let barWidth: CGFloat
    let rainBlue: Color

    @State private var appeared = false

    private var pct: Double { day.precipitationProbability }           // 0–1
    private var label: String { "\(Int(round(pct * 100)))%" }
    private var shortDay: String { String(day.dayName.prefix(3)) }

    var body: some View {
        VStack(spacing: 4) {
            // Percentage label above bar
            Text(pct > 0.05 ? label : "")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(rainBlue)
                .frame(height: 14)

            // Bar itself
            GeometryReader { geo in
                VStack(spacing: 0) {
                    Spacer()
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: pct > 0.05
                                    ? [rainBlue.opacity(0.9), rainBlue.opacity(0.4)]
                                    : [Color.white.opacity(0.08)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(height: appeared ? max(4, pct * geo.size.height) : 4)
                        .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(Double(day.dayName.hashValue % 5) * 0.05), value: appeared)
                }
            }

            // Day label
            Text(shortDay)
                .font(.caption.weight(.medium))
                .foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .onAppear { appeared = true }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(day.dayName): \(label) chance of rain")
    }
}

// MARK: - Rain Window Card

private struct RainWindowCard: View {
    let rain: RainWindow
    let rainBlue: Color

    var body: some View {
        WeatherCard(
            padding: EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16),
            borderColor: rainBlue.opacity(0.25)
        ) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    Circle()
                        .fill(rainBlue.opacity(0.18))
                        .frame(width: 40, height: 40)
                    Image(systemName: "cloud.rain.fill")
                        .symbolRenderingMode(.multicolor)
                        .symbolVariant(.fill)
                        .foregroundStyle(.white)
                        .font(.title3)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(rain.title)
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(rain.timeRange)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(rainBlue)
                    Text(rain.detail)
                        .font(.footnote)
                        .foregroundStyle(AppTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Subviews

private struct HourlyCard: View {
    let hourly: HourlyWeather

    @Environment(\.weatherFormatter) private var weatherFormatter
    var isNow: Bool { hourly.time == "Now" }

    var body: some View {
        WeatherCard(
            cornerRadius: AppTheme.radiusCard,
            padding: EdgeInsets(top: 11, leading: 8, bottom: 11, trailing: 8),
            borderColor: isNow ? Color.white.opacity(0.3) : .clear
        ) {
            VStack(spacing: 6) {
                Text(hourly.time)
                    .font(AppFont.footnoteMedium)
                    .foregroundStyle(isNow ? .white : AppTheme.textSecondary)

                Image(systemName: hourly.symbolName)
                    .symbolRenderingMode(.multicolor)
                    .symbolVariant(.fill)
                    .foregroundStyle(.white)
                    .font(AppFont.title2)
                    .padding(.vertical, 1)

                Text(weatherFormatter.temp(hourly.temperature))
                    .font(AppFont.headline)
                    .foregroundStyle(.white)

                Text("\(Int(hourly.precipitationProbability * 100))%")
                    .font(AppFont.caption)
                    .foregroundStyle(hourly.precipitationProbability >= 0.3
                        ? Color(red: 0.55, green: 0.85, blue: 1.0)
                        : AppTheme.textTertiary)
            }
        }
        .frame(minWidth: 70)
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
        .accessibilityElement(children: .combine)
    }
}

private struct DailyWeatherRow: View {
    let daily: DailyWeather
    let overallMin: Double
    let overallMax: Double
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.weatherFormatter) private var weatherFormatter

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(daily.dayName)
                            .font(AppFont.headline)
                            .foregroundStyle(.white)
                        Text(daily.date)
                            .font(AppFont.footnote)
                            .foregroundStyle(AppTheme.textSecondary)
                        Spacer()
                        Image(systemName: daily.symbolName)
                            .symbolRenderingMode(.multicolor)
                            .symbolVariant(.fill)
                            .foregroundStyle(.white)
                            .font(AppFont.title3)
                        if daily.precipitationProbability > 0 {
                            Text("\(Int(daily.precipitationProbability * 100))%")
                                .font(AppFont.caption2Semibold)
                                .foregroundStyle(Color(red: 0.55, green: 0.85, blue: 1.0))
                        }
                    }

                    HStack(spacing: 8) {
                        Text(weatherFormatter.temp(daily.lowTemperature))
                            .font(AppFont.body)
                            .foregroundStyle(.white)

                        tempBar

                        Text(weatherFormatter.temp(daily.highTemperature))
                            .font(AppFont.bodySemibold)
                            .foregroundStyle(.white)
                    }
                }
            } else {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(daily.dayName)
                            .font(AppFont.headline)
                            .foregroundStyle(.white)
                        Text(daily.date)
                            .font(AppFont.footnote)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    .frame(minWidth: 50, maxWidth: 64, alignment: .leading)

                    VStack(spacing: 2) {
                        Image(systemName: daily.symbolName)
                            .symbolRenderingMode(.multicolor)
                            .symbolVariant(.fill)
                            .foregroundStyle(.white)
                            .font(AppFont.title3)
                        if daily.precipitationProbability > 0 {
                            Text("\(Int(daily.precipitationProbability * 100))%")
                                .font(AppFont.caption2Semibold)
                                .foregroundStyle(Color(red: 0.55, green: 0.85, blue: 1.0))
                        }
                    }
                    .frame(minWidth: 32)

                    Text(weatherFormatter.temp(daily.lowTemperature))
                        .font(AppFont.body)
                        .foregroundStyle(.white)
                        .frame(minWidth: 32, alignment: .trailing)

                    tempBar

                    Text(weatherFormatter.temp(daily.highTemperature))
                        .font(AppFont.bodySemibold)
                        .foregroundStyle(.white)
                        .frame(minWidth: 32, alignment: .trailing)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }

    private var tempBar: some View {
        GeometryReader { geo in
            let totalRange = max(1.0, overallMax - overallMin)
            let startPos = max(0.0, min(1.0, (daily.lowTemperature - overallMin) / totalRange))
            let widthPercent = max(0.05, min(1.0, (daily.highTemperature - daily.lowTemperature) / totalRange))

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.1))

                Capsule()
                    .fill(LinearGradient(colors: [Color(red: 0.4, green: 0.7, blue: 1.0), Color.yellow], startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(4, widthPercent * geo.size.width))
                    .offset(x: max(0, startPos * geo.size.width))
            }
        }
        .frame(height: 4)
    }
}

// MARK: - Previews

#Preview("Forecast") {
    let repo = MockWeatherRepository()
    let uc = GetWeatherUseCase(repository: repo)
    let vm = HomeViewModel(getWeatherUseCase: uc)
    return ForecastView(viewModel: vm)
}

#Preview("Forecast AX3") {
    let repo = MockWeatherRepository()
    let uc = GetWeatherUseCase(repository: repo)
    let vm = HomeViewModel(getWeatherUseCase: uc)
    return ForecastView(viewModel: vm)
        .dynamicTypeSize(.accessibility3)
}

