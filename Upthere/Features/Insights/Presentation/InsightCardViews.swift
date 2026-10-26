import SwiftUI

// MARK: - Insight Card Views

extension InsightsView {
    // MARK: - Rain Window Card

    @ViewBuilder
    func rainWindowCard(rain: InsightEngine.RainWindowResult, hourly: [HourlyWeather]) -> some View {
        InsightCard {
            VStack(alignment: .leading, spacing: 8) {
                InsightBadge(icon: "cloud.rain.fill", label: "Rain window")

                Text(formatTimeRange(start: rain.startDate, end: rain.endDate))
                    .font(.title2.weight(.bold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .accessibilityAddTraits(.isHeader)

                let peakProb = Int((rain.peakProbability * 100).rounded())
                let peakTime = formatHour(rain.peakDate)
                let precipDetail = "Peak precipitation around \(peakTime), \(peakProb)% probability."

                Text(precipDetail)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineSpacing(2)

                // Now indicator
                HStack(spacing: 4) {
                    Text("Now")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(AppTheme.textTertiary)
                    let precipProb = Int(((hourly.first?.precipitationChance ?? 0.0) * 100).rounded())
                    Text("\(precipProb)%")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Spacer()
                    Text("100%")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textTertiary)
                }
                .padding(.top, 4)

                // Precipitation bar chart
                PrecipitationBarChart(hourly: hourly)
                    .frame(height: 80)

                // Time labels
                HourlyTimeLabels(hourly: hourly)

                if RainActivityStateCalculator.isRainWithinTwoHours(rainWindow: rain) {
                    TrackRainButton(
                        cityName: viewModel.displayedWeather?.cityName ?? "Current Location",
                        hourly: hourly
                    )
                    .padding(.top, 6)
                }
            }
        }
    }

    // MARK: - Temperature Rising Card

    @ViewBuilder
    func temperatureRisingCard(trend: InsightEngine.TemperatureTrendResult, hourly: [HourlyWeather]) -> some View {
        InsightCard {
            VStack(alignment: .leading, spacing: 8) {
                InsightBadge(icon: "thermometer.sun.fill", label: "Temperature range")

                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Now")
                                .font(AppFont.captionMedium)
                                .foregroundStyle(AppTheme.textTertiary)
                            Text(weatherFormatter.temp(trend.currentTemperature))
                                .font(AppFont.title)
                                .foregroundStyle(AppTheme.textPrimary)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Next 24 h range")
                                .font(AppFont.captionMedium)
                                .foregroundStyle(AppTheme.textTertiary)
                            HStack(spacing: 4) {
                                Text(weatherFormatter.temp(trend.minTemperature))
                                Image(systemName: "arrow.right")
                                    .font(AppFont.captionSemibold)
                                    .foregroundStyle(AppTheme.textTertiary)
                                Text(weatherFormatter.temp(trend.maxTemperature))
                            }
                            .font(AppFont.headline)
                            .foregroundStyle(AppTheme.textSecondary)
                        }
                    }
                    .padding(.vertical, 4)
                } else {
                    HStack(alignment: .firstTextBaseline, spacing: 16) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Now")
                                .font(AppFont.captionMedium)
                                .foregroundStyle(AppTheme.textTertiary)
                            Text(weatherFormatter.temp(trend.currentTemperature))
                                .font(AppFont.title)
                                .foregroundStyle(AppTheme.textPrimary)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Next 24 h range")
                                .font(AppFont.captionMedium)
                                .foregroundStyle(AppTheme.textTertiary)
                            HStack(spacing: 4) {
                                Text(weatherFormatter.temp(trend.minTemperature))
                                Image(systemName: "arrow.right")
                                    .font(AppFont.captionSemibold)
                                    .foregroundStyle(AppTheme.textTertiary)
                                Text(weatherFormatter.temp(trend.maxTemperature))
                            }
                            .font(AppFont.headline)
                            .foregroundStyle(AppTheme.textSecondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Text("Expected temperature swing of \(Int(trend.temperatureSwing.rounded()))° between \(formatHour(trend.minDate)) and \(formatHour(trend.maxDate)).")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineSpacing(2)

                TemperatureBarChart(hourly: hourly)
                    .frame(height: 80)

                HourlyTimeLabels(hourly: hourly)
            }
        }
    }

    // MARK: - Strongest Winds Card

    @ViewBuilder
    func strongestWindsCard(wind: InsightEngine.StrongestWindResult, hourly: [HourlyWeather]) -> some View {
        let currentWindStr = weatherFormatter.wind(wind.currentWindSpeed)
        let gustWindStr = weatherFormatter.wind(wind.peakGust)
        let peakTime = formatHour(wind.peakDate)

        let windDetail: String = {
            if wind.peakGust > wind.currentWindSpeed {
                return "Expected sustained wind: \(currentWindStr)\nPeak gusts: up to \(gustWindStr) around \(peakTime)"
            } else {
                return "Expected sustained wind: \(currentWindStr)\nPeak gusts: up to \(gustWindStr)"
            }
        }()

        InsightCard {
            VStack(alignment: .leading, spacing: 8) {
                InsightBadge(icon: "wind", label: "Wind conditions")

                Text("Current & Gusts")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .accessibilityAddTraits(.isHeader)

                Text(windDetail)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineSpacing(2)

                HStack(spacing: 4) {
                    Text("Now")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(AppTheme.textTertiary)
                    Text(currentWindStr)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                }
                .padding(.top, 4)

                WindLineChart(hourly: hourly)
                    .frame(height: 80)

                HourlyTimeLabels(hourly: hourly)
            }
        }
    }

    // MARK: - Best Outdoor Conditions Card

    @ViewBuilder
    func bestOutdoorCard(outdoor: InsightEngine.BestOutdoorWindowResult, hourly: [HourlyWeather]) -> some View {
        let maxRain = Int((outdoor.maxPrecipitationChance * 100).rounded())
        let avgWind = Int(outdoor.averageWindSpeed.rounded())
        let avgTemp = Int(outdoor.averageTemperature.rounded())

        let detail: String = {
            if maxRain > 40 {
                return "Most favorable available window despite \(maxRain)% rain chance and \(avgWind) km/h wind."
            } else {
                return "Comfortable ~\(avgTemp)°, low precipitation probability (\(maxRain)%) and moderate wind (\(avgWind) km/h)."
            }
        }()

        InsightCard {
            VStack(alignment: .leading, spacing: 8) {
                InsightBadge(icon: "sun.max.fill", label: "Best outdoor conditions")

                Text(formatTimeRange(start: outdoor.startDate, end: outdoor.endDate))
                    .font(.title2.weight(.bold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .accessibilityAddTraits(.isHeader)

                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineSpacing(2)

                // Now indicator
                HStack(spacing: 4) {
                    Text("Now")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(AppTheme.textTertiary)
                }
                .padding(.top, 4)

                OutdoorTimeline(hourly: hourly, outdoor: outdoor)
                    .padding(.top, 4)
            }
        }
    }

    // MARK: - Highest UV Card

    @ViewBuilder
    func highestUVCard(uv: InsightEngine.PeakUVResult, currentUV: Int, hourly: [HourlyWeather]) -> some View {
        let timeRange = formatTimeRange(start: uv.startDate, end: uv.endDate)
        let uvCategoryStr = uvCategory(for: uv.peakUVIndex)

        InsightCard {
            VStack(alignment: .leading, spacing: 8) {
                InsightBadge(icon: "sun.max.fill", label: "Highest UV")

                Text(timeRange)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .accessibilityAddTraits(.isHeader)

                Text("UV Index: \(uv.peakUVIndex) · \(uvCategoryStr)")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)

                HStack(spacing: 4) {
                    Text("Now")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(AppTheme.textTertiary)
                    Text("\(currentUV)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                }
                .padding(.top, 4)

                UVBarChart(hourly: hourly)
                    .frame(height: 80)

                HourlyTimeLabels(hourly: hourly)
            }
        }
    }


}

