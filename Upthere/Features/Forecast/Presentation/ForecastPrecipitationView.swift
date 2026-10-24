import SwiftUI

// MARK: - Precipitation Section

struct PrecipitationSection: View {
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
                    .foregroundStyle(AppTheme.textPrimary)
                    .accessibilityAddTraits(.isHeader)
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
                            ForecastView.PrecipitationBarChart(days: weather.dailyForecast, rainBlue: rainBlue)
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

// MARK: - Rain Window Card

struct RainWindowCard: View {
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
                        .foregroundStyle(AppTheme.textPrimary)
                        .font(.title3)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(rain.title)
                        .font(.headline)
                        .foregroundStyle(AppTheme.textPrimary)
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
