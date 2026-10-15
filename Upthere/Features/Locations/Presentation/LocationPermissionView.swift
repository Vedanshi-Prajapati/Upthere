import SwiftUI

public struct LocationPermissionView: View {
    public var onAllow: () -> Void
    public var onSearchInstead: () -> Void

    public init(onAllow: @escaping () -> Void, onSearchInstead: @escaping () -> Void) {
        self.onAllow = onAllow
        self.onSearchInstead = onSearchInstead
    }

    public var body: some View {
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
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(AppTheme.accent)
                    }

                    Text("See weather where\nyou are")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)
                        .lineSpacing(2)

                    Text("Get hyperlocal conditions and predictive InsightEngine timing for your current location.")
                        .font(.system(size: 15))
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineSpacing(3)
                }
                .padding(.bottom, 24)

                // InsightEngine value preview card
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AppTheme.accent)
                        Text("Live InsightEngine Preview")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AppTheme.textSecondary)
                    }

                    HStack(spacing: 12) {
                        Image(systemName: "cloud.rain.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(Color(red: 0.45, green: 0.75, blue: 1.0))

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Rain Window · 2:15 PM – 3:30 PM")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(AppTheme.textPrimary)
                            Text("Peak precipitation at 2:45 PM (80% probability)")
                                .font(.system(size: 12))
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                    }
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(AppTheme.cardGlass)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(AppTheme.cardBorder, lineWidth: 0.8)
                )
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
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(
                                RoundedRectangle(cornerRadius: 26, style: .continuous)
                                    .fill(AppTheme.accent)
                            )
                    }

                    Button(action: onSearchInstead) {
                        Text("Search for a city instead")
                            .font(.system(size: 16, weight: .medium))
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
                .font(.system(size: 15))
                .foregroundStyle(AppTheme.accent)
                .frame(width: 22)
            Text(text)
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.textSecondary)
        }
    }
}

#Preview {
    LocationPermissionView(onAllow: {}, onSearchInstead: {})
}
