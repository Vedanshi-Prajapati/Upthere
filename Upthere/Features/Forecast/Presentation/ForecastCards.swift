import SwiftUI

// MARK: - Subviews

struct HourlyCard: View {
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
                    .foregroundStyle(isNow ? AppTheme.textPrimary : AppTheme.textSecondary)

                Image(systemName: hourly.symbolName)
                    .symbolRenderingMode(.multicolor)
                    .symbolVariant(.fill)
                    .foregroundStyle(AppTheme.textPrimary)
                    .font(AppFont.title2)
                    .padding(.vertical, 1)

                Text(weatherFormatter.temp(hourly.temperature))
                    .font(AppFont.headline)
                    .foregroundStyle(AppTheme.textPrimary)

                Text("\(Int(hourly.precipitationProbability * 100))%")
                    .font(AppFont.caption)
                    .foregroundStyle(hourly.precipitationProbability >= 0.3
                        ? AppTheme.rainBlueLight
                        : AppTheme.textTertiary)
            }
        }
        .frame(minWidth: 70)
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
        .accessibilityElement(children: .combine)
    }
}

struct DailyWeatherRow: View {
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
                            .foregroundStyle(AppTheme.textPrimary)
                        Text(daily.date)
                            .font(AppFont.footnote)
                            .foregroundStyle(AppTheme.textSecondary)
                        Spacer()
                        Image(systemName: daily.symbolName)
                            .symbolRenderingMode(.multicolor)
                            .symbolVariant(.fill)
                            .foregroundStyle(AppTheme.textPrimary)
                            .font(AppFont.title3)
                        if daily.precipitationProbability > 0 {
                            Text("\(Int(daily.precipitationProbability * 100))%")
                                .font(AppFont.caption2Semibold)
                                .foregroundStyle(AppTheme.rainBlueLight)
                        }
                    }

                    HStack(spacing: 8) {
                        Text(weatherFormatter.temp(daily.lowTemperature))
                            .font(AppFont.body)
                            .foregroundStyle(AppTheme.textSecondary)

                        tempBar

                        Text(weatherFormatter.temp(daily.highTemperature))
                            .font(AppFont.bodySemibold)
                            .foregroundStyle(AppTheme.textPrimary)
                    }
                }
            } else {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(daily.dayName)
                            .font(AppFont.headline)
                            .foregroundStyle(AppTheme.textPrimary)
                        Text(daily.date)
                            .font(AppFont.footnote)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    .frame(minWidth: 50, maxWidth: 64, alignment: .leading)

                    VStack(spacing: 2) {
                        Image(systemName: daily.symbolName)
                            .symbolRenderingMode(.multicolor)
                            .symbolVariant(.fill)
                            .foregroundStyle(AppTheme.textPrimary)
                            .font(AppFont.title3)
                        if daily.precipitationProbability > 0 {
                            Text("\(Int(daily.precipitationProbability * 100))%")
                                .font(AppFont.caption2Semibold)
                                .foregroundStyle(AppTheme.rainBlueLight)
                        }
                    }
                    .frame(minWidth: 32)

                    Text(weatherFormatter.temp(daily.lowTemperature))
                        .font(AppFont.body)
                        .foregroundStyle(AppTheme.textSecondary)
                        .frame(minWidth: 32, alignment: .trailing)

                    tempBar

                    Text(weatherFormatter.temp(daily.highTemperature))
                        .font(AppFont.bodySemibold)
                        .foregroundStyle(AppTheme.textPrimary)
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
