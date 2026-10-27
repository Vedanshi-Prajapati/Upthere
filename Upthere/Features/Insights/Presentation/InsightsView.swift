import SwiftUI

struct InsightsView: View {
    @State var viewModel: HomeViewModel
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    @Environment(\.weatherFormatter) var weatherFormatter

    init(viewModel: HomeViewModel) {
        self._viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ZStack {
            WeatherBackgroundView(
                condition: viewModel.displayedWeather?.condition,
                symbolName: viewModel.displayedWeather?.weatherSymbolName
            )

            if let weather = viewModel.displayedWeather {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        header
                        alertSection(weather: weather)
                        insightsSection(weather: weather)
                        footer
                        AttributionView()
                            .padding(.top, 16)
                            .padding(.horizontal, 20)
                    }
                }
                .scrollEdgeEffectStyle(.soft, for: .top)
                .scrollEdgeEffectStyle(.soft, for: .bottom)
                .contentMargins(.bottom, AppTheme.tabBarClearance, for: .scrollContent)
            } else {
                switch viewModel.state {
                case .idle, .loading:
                    ProgressView().tint(.white)
                case .error(let msg, _):
                    VStack(spacing: 8) {
                        Text(msg)
                            .foregroundStyle(AppTheme.textSecondary)
                        Button("Retry") {
                            Task { await viewModel.refreshWeather() }
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.accent)
                        .accessibilityIdentifier("insights_retry_button")
                    }
                    .padding(.horizontal, 20)
                case .loaded:
                    ProgressView().tint(.white)
                }
            }
        }
        .task {
            if viewModel.displayedWeather == nil {
                await viewModel.loadWeather()
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Insights")
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(AppTheme.textPrimary)
                .accessibilityAddTraits(.isHeader)
            Text("What the forecast actually means.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 24)
    }

    // MARK: - Weather Alerts

    private func alertSection(weather: Weather) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Weather alerts")
                        .font(AppFont.title3Bold)
                        .foregroundStyle(AppTheme.textPrimary)
                        .accessibilityAddTraits(.isHeader)
                    Text("Official source")
                        .font(AppFont.subheadlineMedium)
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .padding(.horizontal, 20)
            } else {
                HStack {
                    Text("Weather alerts")
                        .font(AppFont.title3Bold)
                        .foregroundStyle(AppTheme.textPrimary)
                        .accessibilityAddTraits(.isHeader)
                    Spacer()
                    Text("Official source")
                        .font(AppFont.subheadlineMedium)
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .padding(.horizontal, 20)
            }

            if let alert = weather.alert {
                WeatherCard(
                    cornerRadius: AppTheme.radiusCard,
                    padding: EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16),
                    borderColor: AppTheme.alertAmber.opacity(0.3)
                ) {
                    VStack(alignment: .leading, spacing: 12) {
                        // Badge
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundStyle(AppTheme.alertAmber)
                            Text(alert.severity != nil ? "\(alert.severity?.capitalized ?? "") Weather Alert" : "Official weather alert")
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(AppTheme.textSecondary)
                        }

                        // Title
                        Text(alert.title)
                            .font(.headline)
                            .foregroundStyle(AppTheme.textPrimary)
                            .accessibilityAddTraits(.isHeader)

                        // Description
                        if let details = alert.details, !details.isEmpty {
                            Text(details)
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.textSecondary)
                                .lineSpacing(3)
                        }

                        // Source
                        let sourceText = alert.source.isEmpty ? "Meteorological Agency" : alert.source
                        Text("Issued by \(sourceText) · \(alert.validUntil)")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textTertiary)
                            .lineSpacing(2)

                        Rectangle()
                            .fill(Color.white.opacity(0.10))
                            .frame(height: 1)

                        // Attribution link
                        HStack {
                            Text("Read official attribution")
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.textPrimary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppTheme.textTertiary)
                        }
                    }
                }
                .padding(.horizontal, 20)
            } else {
                // No active alerts state card
                WeatherCard(
                    cornerRadius: AppTheme.radiusCard,
                    padding: EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
                ) {
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.shield.fill")
                            .font(.title3)
                            .foregroundStyle(Color.green.opacity(0.85))

                        VStack(alignment: .leading, spacing: 2) {
                            Text("No active weather alerts")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.textPrimary)
                                .accessibilityAddTraits(.isHeader)
                            Text("No severe weather warnings are currently in effect for this region.")
                                .font(.footnote)
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                        Spacer()
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .padding(.bottom, 28)
    }

    // MARK: - UpThere Insights

    private let insightEngine = InsightEngine()

    func formatHour(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "ha"
        return formatter.string(from: date).lowercased().replacingOccurrences(of: "m", with: "")
    }

    func formatTimeRange(start: Date, end: Date) -> String {
        let s = formatHour(start)
        let e = formatHour(end)
        return s == e ? "Around \(s)" : "\(s) – \(e)"
    }

    private func insightsSection(weather: Weather) -> some View {
        let hourly = weather.hourlyForecast
        let rainWindow = insightEngine.rainWindow(from: hourly)
        let tempTrend = insightEngine.temperatureTrend(from: hourly, currentTemperature: weather.temperature)
        let strongWind = insightEngine.strongestWind(from: hourly)
        let outdoorWindow = insightEngine.bestOutdoorWindow(from: hourly)
        let peakUV = insightEngine.peakUV(from: hourly)
        let cloudChange = insightEngine.cloudChange(from: hourly)

        return VStack(alignment: .leading, spacing: 16) {
            Text("UpThere insights")
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppTheme.textPrimary)
                .accessibilityAddTraits(.isHeader)
                .padding(.horizontal, 20)

            if let rain = rainWindow {
                rainWindowCard(rain: rain, hourly: hourly)
            }

            if let trend = tempTrend {
                temperatureRisingCard(trend: trend, hourly: hourly)
            }

            if let wind = strongWind {
                strongestWindsCard(wind: wind, hourly: hourly)
            }

            if let outdoor = outdoorWindow {
                bestOutdoorCard(outdoor: outdoor, hourly: hourly)
            }

            if let uv = peakUV {
                highestUVCard(uv: uv, currentUV: weather.uvIndex, hourly: hourly)
            }

            if let cloud = cloudChange {
                weatherChangingCard(cloud: cloud, hourly: hourly)
            }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        Text("Insights are UpThere's interpretation of forecast data and may change as forecasts update. For official warnings, refer to your national weather service.")
            .font(.caption)
            .foregroundStyle(AppTheme.textTertiary)
            .lineSpacing(3)
            .padding(.horizontal, 20)
            .padding(.top, 20)
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Insights") {
    let repo = MockWeatherRepository()
    let uc = GetWeatherUseCase(repository: repo)
    let vm = HomeViewModel(getWeatherUseCase: uc)
    InsightsView(viewModel: vm)
}

#Preview("Insights AX3") {
    let repo = MockWeatherRepository()
    let uc = GetWeatherUseCase(repository: repo)
    let vm = HomeViewModel(getWeatherUseCase: uc)
    InsightsView(viewModel: vm)
        .dynamicTypeSize(.accessibility3)
}
#endif
