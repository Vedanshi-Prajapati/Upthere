import SwiftUI

/// Network error state shown when weather data cannot be fetched.
public struct NetworkErrorView: View {
    public var onRetry: () -> Void

    public init(onRetry: @escaping () -> Void) {
        self.onRetry = onRetry
    }

    public var body: some View {
        ZStack {
            // Darker, desaturated gradient for error state
            LinearGradient(
                colors: [
                    Color(red: 0.22, green: 0.30, blue: 0.44),
                    Color(red: 0.12, green: 0.17, blue: 0.30)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 20) {
                // Wifi-off icon
                Image(systemName: "wifi.slash")
                    .font(.system(size: 48, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.bottom, 4)

                Text("Weather unavailable")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(.white)

                Text("We couldn't retrieve the latest forecast.\nCheck your connection and try again.")
                    .font(.system(size: 16))
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)

                // Try again button
                Button(action: onRetry) {
                    Text("Try again")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: 240)
                        .frame(height: 54)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.14))
                                .overlay(
                                    Capsule()
                                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                                )
                        )
                }
                .padding(.top, 8)
            }
            .padding(.horizontal, 40)
        }
    }
}

#Preview {
    NetworkErrorView(onRetry: {})
}
