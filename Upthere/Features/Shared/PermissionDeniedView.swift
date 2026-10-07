import SwiftUI

/// Permission denied screen shown when location access has been denied.
public struct PermissionDeniedView: View {
    public var onSearch: () -> Void
    public var onOpenSettings: () -> Void

    public init(onSearch: @escaping () -> Void, onOpenSettings: @escaping () -> Void) {
        self.onSearch = onSearch
        self.onOpenSettings = onOpenSettings
    }

    public var body: some View {
        ZStack {
            AppTheme.backgroundGradient.ignoresSafeArea()

            VStack(spacing: 20) {
                // Location icon
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 52, weight: .medium))
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(.bottom, 4)

                Text("Location unavailable")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(.white)

                Text("You can still search for a location manually,\nor turn on access in Settings › Privacy ›\nLocation Services.")
                    .font(.system(size: 16))
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)

                VStack(spacing: 12) {
                    // Search button (primary)
                    Button(action: onSearch) {
                        Text("Search for a location")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: 280)
                            .frame(height: 54)
                            .background(
                                Capsule()
                                    .fill(AppTheme.accent)
                            )
                    }

                    // Open settings button (secondary)
                    Button(action: onOpenSettings) {
                        Text("Open settings")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: 280)
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
                }
                .padding(.top, 8)
            }
            .padding(.horizontal, 40)
        }
    }
}

#Preview {
    PermissionDeniedView(onSearch: {}, onOpenSettings: {})
}
