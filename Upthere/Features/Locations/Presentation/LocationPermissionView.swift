import SwiftUI

struct LocationPermissionView: View {
    var onAllow: () -> Void
    var onSearchInstead: () -> Void

    init(onAllow: @escaping () -> Void, onSearchInstead: @escaping () -> Void) {
        self.onAllow = onAllow
        self.onSearchInstead = onSearchInstead
    }

    var body: some View {
        ZStack {
            AppTheme.backgroundGradient.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                Spacer(minLength: 24)

                // Tightly grouped introductory block
                VStack(alignment: .leading, spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(AppTheme.cardGlass)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(AppTheme.cardBorder, lineWidth: 1)
                            )
                            .frame(width: 52, height: 52)
                        Image(systemName: "location.fill")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(AppTheme.accent)
                    }

                    Text("See weather where\nyou are")
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(AppTheme.textPrimary)
                        .lineSpacing(2)
                        .accessibilityAddTraits(.isHeader)

                    Text("Get hyperlocal conditions and predictive InsightEngine timing for your current location.")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineSpacing(3)
                }
                .padding(.bottom, 24)

                // InsightEngine value preview card
                WeatherCard(cornerRadius: AppTheme.radiusCard, padding: EdgeInsets(top: 14, leading: 14, bottom: 14, trailing: 14)) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 6) {
                            Image(systemName: "sparkles")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppTheme.accent)
                            Text("Live InsightEngine Preview")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppTheme.textSecondary)
                        }

                        HStack(spacing: 12) {
                            Image(systemName: "cloud.rain.fill")
                                .font(.title2)
                                .foregroundStyle(Color(red: 0.45, green: 0.75, blue: 1.0))

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Rain Window · 2:15 PM – 3:30 PM")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(AppTheme.textPrimary)
                                Text("Peak precipitation at 2:45 PM (80% probability)")
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                        }
                    }
                }
                .padding(.bottom, 24)

                // Concise benefits
                VStack(alignment: .leading, spacing: 14) {
                    benefitRow(icon: "clock.arrow.circlepath", text: "Minute-by-minute precipitation tracking")
                    benefitRow(icon: "wind", text: "Peak gust & temperature swing forecasts")
                    benefitRow(icon: "lock.shield.fill", text: "Privacy-first: used only to fetch WeatherKit telemetry")
                }

                Spacer(minLength: 24)

                // Actions
                VStack(spacing: 12) {
                    Button(action: onAllow) {
                        Text("Allow location")
                            .font(.headline)
                            .foregroundStyle(AppTheme.textPrimary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(
                                RoundedRectangle(cornerRadius: 26, style: .continuous)
                                    .fill(AppTheme.accent)
                            )
                    }

                    Button(action: onSearchInstead) {
                        Text("Search for a city instead")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(AppTheme.textSecondary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                    }
                }
                .padding(.bottom, 12)
            }
            .padding(.horizontal, 28)
        }
    }

    private func benefitRow(icon: String, text: String) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(AppTheme.accent)
                .frame(width: 22)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
        }
    }
}

#Preview {
    LocationPermissionView(onAllow: {}, onSearchInstead: {})
}
