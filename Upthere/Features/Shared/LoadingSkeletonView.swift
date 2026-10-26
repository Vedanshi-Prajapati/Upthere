import SwiftUI

/// Skeleton loading screen shown while weather data is being fetched.
/// Displays animated shimmer placeholders matching the home screen layout.
struct LoadingSkeletonView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shimmer = false

    init() {}

    var body: some View {
        ZStack {
            Color(red: 0.08, green: 0.10, blue: 0.14).ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                // "Updating forecast..." header
                HStack(spacing: 8) {
                    ProgressView()
                        .tint(.white.opacity(0.6))
                        .scaleEffect(0.8)
                    Text("Updating forecast...")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 20)

                // Skeleton header area
                VStack(alignment: .leading, spacing: 8) {
                    SkeletonLine(width: 120, height: 14)
                    SkeletonLine(width: 160, height: 10)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)

                // Skeleton temperature block
                VStack(alignment: .leading, spacing: 8) {
                    SkeletonRect(width: 140, height: 60)
                    SkeletonLine(width: 200, height: 12)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 28)

                // Skeleton card 1
                SkeletonCard(height: 160)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)

                // Skeleton card 2
                SkeletonCard(height: 140)
                    .padding(.horizontal, 20)

                Spacer()
            }
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                shimmer = true
            }
        }
        .environment(\.shimmerActive, shimmer)
    }
}

// MARK: - Skeleton Components

private struct SkeletonLine: View {
    let width: CGFloat
    let height: CGFloat
    @Environment(\.shimmerActive) private var shimmer

    var body: some View {
        RoundedRectangle(cornerRadius: height / 2, style: .continuous)
            .fill(Color.white.opacity(shimmer ? 0.12 : 0.06))
            .frame(width: width, height: height)
    }
}

private struct SkeletonRect: View {
    let width: CGFloat
    let height: CGFloat
    @Environment(\.shimmerActive) private var shimmer

    var body: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(Color.white.opacity(shimmer ? 0.12 : 0.06))
            .frame(width: width, height: height)
    }
}

private struct SkeletonCard: View {
    let height: CGFloat
    @Environment(\.shimmerActive) private var shimmer

    var body: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color.white.opacity(shimmer ? 0.10 : 0.05))
            .frame(height: height)
    }
}

// MARK: - Shimmer Environment Key

private struct ShimmerActiveKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

extension EnvironmentValues {
    fileprivate var shimmerActive: Bool {
        get { self[ShimmerActiveKey.self] }
        set { self[ShimmerActiveKey.self] = newValue }
    }
}

#Preview {
    LoadingSkeletonView()
}
