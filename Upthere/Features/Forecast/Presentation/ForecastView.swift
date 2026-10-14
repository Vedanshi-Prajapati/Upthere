import SwiftUI

public struct ForecastView: View {
    @State private var viewModel: HomeViewModel
    @State private var selectedTab: ForecastTab = .daily

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
                        PrecipitationSection(weather: weather)
                            .padding(.horizontal, 20)
                    } else {
                        hourlyView(weather: weather)
                    }
                }
                .padding(.bottom, 110)
            }
            .padding(.top, 16)
        }
    }

    private func header(weather: Weather) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Forecast")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(.white)
            Text(weather.cityName)
                .font(.system(size: 16))
                .foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 62)
        .padding(.bottom, 24)
    }

    private var picker: some View {
        HStack(spacing: 0) {
            pickerButton(title: "Hourly", tab: .hourly)
            pickerButton(title: "Daily", tab: .daily)
        }
        .padding(4)
        .background(
            Capsule().stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
        .padding(.horizontal, 20)
    }

    private func pickerButton(title: String, tab: ForecastTab) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedTab = tab
            }
        } label: {
            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    Group {
                        if selectedTab == tab {
                            Capsule().fill(Color.white.opacity(0.2))
                        } else {
                            Color.clear
                        }
                    }
                )
        }
    }

    private func dailyView(weather: Weather) -> some View {
        let lows = weather.dailyForecast.map(\.lowTemperature)
        let highs = weather.dailyForecast.map(\.highTemperature)
        let overallMin = lows.min() ?? 10.0
        let overallMax = highs.max() ?? 35.0

        return VStack(spacing: 0) {
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
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(AppTheme.cardGlass)
        )
        .padding(.horizontal, 20)
    }

    private func hourlyView(weather: Weather) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(weather.hourlyForecast) { hourly in
                        HourlyCard(hourly: hourly)
                    }
                }
                .padding(.horizontal, 20)
            }

            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Now")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white)
                    Spacer()
                    Text(weather.condition)
                        .font(.system(size: 15))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .padding(.horizontal, 20)

                let currentT = WeatherFormatter.shared.temp(weather.temperature)
                let feelsT = WeatherFormatter.shared.temp(weather.feelsLike)
                let precipVal = WeatherFormatter.shared.precipitation(0.0)

                let rows: [(String, String, String, String, String, String)] = [
                    ("Temperature", currentT, "Feels like \(feelsT)",
                     "Precipitation", "\(weather.precipitationChance)%", precipVal),
                    ("Wind", WeatherFormatter.shared.wind(weather.windSpeed), weather.windDirection,
                     "UV Index", "\(weather.uvIndex)", weather.uvDescription),
                    ("Humidity", "\(weather.humidity)%", "Dew point \(WeatherFormatter.shared.temp(weather.dewPoint))",
                     "Visibility", WeatherFormatter.shared.visibility(weather.visibility), weather.visibilityDescription),
                ]

                VStack(spacing: 0) {
                    ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                        HStack(alignment: .top, spacing: 0) {
                            forecastMetricCell(title: row.0, value: row.1, subtitle: row.2)
                            Rectangle().fill(Color.white.opacity(0.1)).frame(width: 1)
                            forecastMetricCell(title: row.3, value: row.4, subtitle: row.5)
                        }
                        if rows.firstIndex(where: { $0.0 == row.0 }) != rows.count - 1 {
                            Rectangle().fill(Color.white.opacity(0.1)).frame(height: 1)
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(AppTheme.cardGlass)
                )
                .padding(.horizontal, 20)
            }
        }
    }

    private func forecastMetricCell(title: String, value: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.textSecondary)
            Text(value)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
            Text(subtitle)
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.textSecondary)
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

    private let rainBlue = Color(red: 0.35, green: 0.65, blue: 1.0)

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section header
            HStack(spacing: 8) {
                Image(systemName: "drop.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(rainBlue)
                Text("Precipitation")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                Spacer()
                Text("\(weather.chanceOfRain)% today")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(rainBlue)
            }

            // Bar chart card
            VStack(alignment: .leading, spacing: 14) {
                Text("Daily chance of rain")
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.textSecondary)

                if weather.dailyForecast.isEmpty {
                    Text("No forecast data available")
                        .font(.system(size: 14))
                        .foregroundStyle(AppTheme.textTertiary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 20)
                } else {
                    PrecipitationBarChart(days: weather.dailyForecast, rainBlue: rainBlue)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(AppTheme.cardGlass)
            )

            // Rain window card (if active)
            if let rain = weather.rainWindow {
                RainWindowCard(rain: rain, rainBlue: rainBlue)
            }
        }
    }
}

// MARK: - Precipitation Bar Chart

private struct PrecipitationBarChart: View {
    let days: [DailyWeather]
    let rainBlue: Color

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
                .font(.system(size: 10, weight: .semibold))
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
                .font(.system(size: 11, weight: .medium))
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
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(rainBlue.opacity(0.18))
                    .frame(width: 40, height: 40)
                WeatherIllustrationView(type: .rainy, size: 28, animated: true)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(rain.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                Text(rain.timeRange)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(rainBlue)
                Text(rain.detail)
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(AppTheme.cardGlass)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(rainBlue.opacity(0.25), lineWidth: 1)
                )
        )
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Subviews

private struct HourlyCard: View {
    let hourly: HourlyWeather

    var isNow: Bool { hourly.time == "Now" }

    var body: some View {
        VStack(spacing: 8) {
            Text(hourly.time)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(isNow ? .white : AppTheme.textSecondary)

            WeatherIllustrationView(condition: nil, symbolName: hourly.symbolName, size: 30, animated: false)
                .frame(height: 30)
                .padding(.vertical, 2)

            Text(WeatherFormatter.shared.temp(hourly.temperature))
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)

            Text("\(Int(hourly.precipitationProbability * 100))%")
                .font(.system(size: 13))
                .foregroundStyle(hourly.precipitationProbability >= 0.3
                    ? Color(red: 0.55, green: 0.85, blue: 1.0)
                    : AppTheme.textSecondary)
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 12)
        .frame(width: 80)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(isNow ? Color.white.opacity(0.15) : AppTheme.cardGlass)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(isNow ? Color.white.opacity(0.3) : Color.clear, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }
}

private struct DailyWeatherRow: View {
    let daily: DailyWeather
    let overallMin: Double
    let overallMax: Double

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(daily.dayName)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                Text(daily.date)
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .frame(width: 60, alignment: .leading)

            VStack(spacing: 2) {
                WeatherIllustrationView(condition: nil, symbolName: daily.symbolName, size: 26, animated: false)
                    .frame(height: 26)
                if daily.precipitationProbability > 0 {
                    Text("\(Int(daily.precipitationProbability * 100))%")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color(red: 0.55, green: 0.85, blue: 1.0))
                }
            }
            .frame(width: 40)

            Text(WeatherFormatter.shared.temp(daily.lowTemperature))
                .font(.system(size: 17))
                .foregroundStyle(.white)
                .frame(width: 38, alignment: .trailing)

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

            Text(WeatherFormatter.shared.temp(daily.highTemperature))
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 38, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }
}

