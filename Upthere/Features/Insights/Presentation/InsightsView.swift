import SwiftUI

public struct InsightsView: View {
    public init() {}
    public var body: some View {
        ZStack {
            AppTheme.backgroundGradient.ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "sparkles")
                    .font(.system(size: 48))
                    .foregroundStyle(.white.opacity(0.5))
                Text("Insights")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white)
                Text("Coming soon")
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
    }
}
