import SwiftUI

struct TrackRainButton: View {
    let cityName: String
    let hourly: [HourlyWeather]
    @State private var isTracking: Bool = false

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    init(cityName: String, hourly: [HourlyWeather]) {
        self.cityName = cityName
        self.hourly = hourly
        self._isTracking = State(initialValue: RainActivityManager.shared.hasActiveActivity)
    }

    var body: some View {
        Group {
            if reduceTransparency {
                if isTracking {
                    trackButton.buttonStyle(.borderedProminent).tint(.cyan)
                } else {
                    trackButton.buttonStyle(.bordered).tint(.white)
                }
            } else {
                if isTracking {
                    trackButton.buttonStyle(.glassProminent)
                } else {
                    trackButton.buttonStyle(.glass)
                }
            }
        }
        .accessibilityLabel(isTracking ? "Tracking rain live activity active" : "Track rain in Live Activity")
        .accessibilityHint("Starts a Lock Screen and Dynamic Island live activity for upcoming rain")
        .accessibilityIdentifier("track_rain_button")
        .onAppear {
            isTracking = RainActivityManager.shared.hasActiveActivity
        }
    }

    private var trackButton: some View {
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
                    .foregroundStyle(AppTheme.textPrimary)

                Text(isTracking ? "Tracking rain" : "Track rain")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
        }
    }
}
