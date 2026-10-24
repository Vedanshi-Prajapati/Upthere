import SwiftUI

/// Splash screen shown on app launch.
/// Displays the UpThere logo, app name, and tagline.
public struct SplashView: View {
    public init() {}

    public var body: some View {
        ZStack {
            AppTheme.backgroundGradient.ignoresSafeArea()

            VStack(spacing: 16) {
                // App icon
                ZStack {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.30, green: 0.55, blue: 0.88),
                                    Color(red: 0.18, green: 0.42, blue: 0.78)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .stroke(Color.white.opacity(0.15), lineWidth: 1)
                        )
                        .frame(width: 80, height: 80)
                        .shadow(color: .black.opacity(0.25), radius: 20, y: 10)

                    // Stylized weather icon
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.title.weight(.medium))
                        .foregroundStyle(AppTheme.textPrimary)
                        .overlay(
                            Circle()
                                .fill(AppTheme.alertAmber)
                                .frame(width: 6, height: 6)
                                .offset(y: 8),
                            alignment: .bottom
                        )
                }
                .padding(.bottom, 8)

                Text("UpThere")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .accessibilityAddTraits(.isHeader)

                Text("Weather, understood.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
    }
}

#Preview {
    SplashView()
}
