import SwiftUI

public struct LocationPermissionView: View {
    public var onAllow: () -> Void
    public var onSearchInstead: () -> Void

    public init(onAllow: @escaping () -> Void, onSearchInstead: @escaping () -> Void) {
        self.onAllow = onAllow
        self.onSearchInstead = onSearchInstead
    }

    private let features: [(String, String)] = [
        ("sparkles", "Insights tuned to your exact area"),
        ("umbrella.fill", "Rain timing for where you are now"),
        ("info.circle", "Location is only shared with WeatherKit to fetch forecasts"),
    ]

    public var body: some View {
        ZStack {
            AppTheme.backgroundGradient.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                Spacer()

                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(AppTheme.cardGlass)
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(AppTheme.cardBorder, lineWidth: 1)
                        )
                        .frame(width: 64, height: 64)
                    Image(systemName: "location.fill")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .padding(.bottom, 32)

                Text("See weather where\nyou are")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(.white)
                    .lineSpacing(2)
                    .padding(.bottom, 14)

                Text("UpThere uses your location to provide local weather and forecast insights.")
                    .font(.system(size: 16))
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineSpacing(3)
                    .padding(.bottom, 40)

                VStack(alignment: .leading, spacing: 22) {
                    ForEach(features, id: \.0) { icon, text in
                        HStack(alignment: .top, spacing: 16) {
                            Image(systemName: icon)
                                .font(.system(size: 16))
                                .foregroundStyle(AppTheme.textSecondary)
                                .frame(width: 22)
                            Text(text)
                                .font(.system(size: 15))
                                .foregroundStyle(AppTheme.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                Spacer()

                VStack(spacing: 12) {
                    Button(action: onAllow) {
                        Text("Allow location")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(
                                RoundedRectangle(cornerRadius: 27, style: .continuous)
                                    .fill(AppTheme.accent)
                            )
                    }

                    Button(action: onSearchInstead) {
                        Text("Search for a location instead")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(AppTheme.textSecondary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(
                                RoundedRectangle(cornerRadius: 27, style: .continuous)
                                    .fill(Color.white.opacity(0.12))
                            )
                    }
                }
                .padding(.bottom, 8)
            }
            .padding(.horizontal, 28)
        }
    }
}

#Preview {
    LocationPermissionView(onAllow: {}, onSearchInstead: {})
}
