import SwiftUI

struct ForecastView: View {
    @State private var viewModel: HomeViewModel
    @State private var selectedTab: ForecastTab = .daily
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.weatherFormatter) private var weatherFormatter
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    enum ForecastTab {
        case hourly, daily
    }

    init(viewModel: HomeViewModel) {
        self._viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ZStack {
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

                    AttributionView()
                        .padding(.top, 8)
                }
            }
            .scrollEdgeEffectStyle(.soft, for: .top)
            .scrollEdgeEffectStyle(.soft, for: .bottom)
            .contentMargins(.bottom, AppTheme.tabBarClearance, for: .scrollContent)
            .padding(.top, 16)
        }
    }

    private func header(weather: Weather) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Forecast")
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(AppTheme.textPrimary)
                .accessibilityAddTraits(.isHeader)
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
        Group {
            if reduceTransparency {
                HStack(spacing: 2) {
                    pickerButton(title: "Hourly", tab: .hourly)
                    pickerButton(title: "Daily", tab: .daily)
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(Color(white: 0.18), in: Capsule())
            } else {
                GlassEffectContainer(spacing: 2) {
                    HStack(spacing: 2) {
                        pickerButton(title: "Hourly", tab: .hourly)
                        pickerButton(title: "Daily", tab: .daily)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
    }

    private func pickerButton(title: String, tab: ForecastTab) -> some View {
        Button {
            withAnimation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.7)) {
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
        .accessibilityIdentifier("forecast_\(title.lowercased())_button")
        .accessibilityLabel("\(title) forecast")
        .accessibilityAddTraits(selectedTab == tab ? [.isSelected, .isButton] : [.isButton])
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
                        .foregroundStyle(AppTheme.textPrimary)
                        .accessibilityAddTraits(.isHeader)
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
