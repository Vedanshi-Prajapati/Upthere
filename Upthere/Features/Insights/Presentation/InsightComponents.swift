import SwiftUI

// MARK: - Reusable Components

extension InsightsView {
    struct InsightCard<Content: View>: View {
        @ViewBuilder let content: Content

        var body: some View {
            WeatherCard(
                cornerRadius: AppTheme.radiusCard,
                padding: EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
            ) {
                content
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 20)
        }
    }

    struct InsightBadge: View {
        let icon: String
        let label: String

        var body: some View {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.footnote)
                    .foregroundStyle(Color.white.opacity(0.75))
                Text(label)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .padding(.bottom, 2)
        }
    }

    struct HourlyTimeLabels: View {
        let hourly: [HourlyWeather]

        var body: some View {
            HStack(spacing: 0) {
                ForEach(Array(hourly.enumerated()), id: \.element.id) { index, hour in
                    if index % 2 == 0 {
                        Text(hour.time)
                            .font(.caption2)
                            .foregroundStyle(AppTheme.textTertiary)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }

    func uvCategory(for value: Int) -> String {
        switch value {
        case 0...2: return "Low"
        case 3...5: return "Moderate"
        case 6...7: return "High"
        case 8...10: return "Very High"
        default: return "Extreme"
        }
    }

    // MARK: - Weather Changing Card

    @ViewBuilder
    func weatherChangingCard(cloud: InsightEngine.CloudChangeResult, hourly: [HourlyWeather]) -> some View {
        let heading = cloud.isClearing ? "Skies clearing" : "Cloud cover increasing"
        let startPct = Int((cloud.initialCloudCover * 100).rounded())
        let endPct = Int((cloud.targetCloudCover * 100).rounded())
        let timeStr = formatHour(cloud.changeDate)

        let description: String = {
            if cloud.isClearing {
                return "Skies clearing around \(timeStr) as cloud cover drops from \(startPct)% to \(endPct)%."
            } else {
                return "Cloud cover increases significantly around \(timeStr), from \(startPct)% to \(endPct)%."
            }
        }()

        InsightCard {
            VStack(alignment: .leading, spacing: 8) {
                InsightBadge(icon: "cloud.sun.fill", label: "Weather changing")

                Text(heading)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)

                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineSpacing(2)

                CloudCoverChart(hourly: hourly, shiftIndex: cloud.changeIndex)
            }
        }
    }
}
