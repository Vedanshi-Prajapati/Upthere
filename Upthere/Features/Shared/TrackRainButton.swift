import SwiftUI

public struct TrackRainButton: View {
    public let cityName: String
    public let hourly: [HourlyWeather]
    @State private var isTracking: Bool = false

    public init(cityName: String, hourly: [HourlyWeather]) {
        self.cityName = cityName
        self.hourly = hourly
        self._isTracking = State(initialValue: RainActivityManager.shared.hasActiveActivity)
    }

    public var body: some View {
        Button {
            Task {
                if isTracking {
                    await RainActivityManager.shared.endAllRainActivities()
                    isTracking = false
                } else {
                    let success = await RainActivityManager.shared.startRainActivity(
                        city: cityName,
                        hourly: hourly
                    )
                    if success {
                        isTracking = true
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: isTracking ? "checkmark.circle.fill" : "cloud.rain.fill")
                    .font(.subheadline.weight(.semibold))

                Text(isTracking ? "Tracking rain" : "Track rain")
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isTracking ? Color.cyan.opacity(0.3) : AppTheme.accent)
            )
            .overlay(
                Capsule()
                    .stroke(isTracking ? Color.cyan.opacity(0.8) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isTracking ? "Tracking rain live activity active" : "Track rain in Live Activity")
        .accessibilityHint("Starts a Lock Screen and Dynamic Island live activity for upcoming rain")
        .onAppear {
            isTracking = RainActivityManager.shared.hasActiveActivity
        }
    }
}
