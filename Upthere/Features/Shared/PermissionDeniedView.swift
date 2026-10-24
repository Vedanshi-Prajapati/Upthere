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
                    .font(.largeTitle)
                    .foregroundStyle(AppTheme.textSecondary)
                    .padding(.bottom, 4)

                Text("Location unavailable")
                    .font(.title.weight(.bold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .accessibilityAddTraits(.isHeader)

                Text("You can still search for a location manually,\nor turn on access in Settings › Privacy ›\nLocation Services.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)

                VStack(spacing: 12) {
                    // Search button (primary)
                    Button(action: onSearch) {
                        Text("Search for a location")
                            .font(.headline)
                            .foregroundStyle(AppTheme.textPrimary)
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
                            .font(.headline)
                            .foregroundStyle(AppTheme.textPrimary)
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
