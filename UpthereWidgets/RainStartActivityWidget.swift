import WidgetKit
import SwiftUI

public struct RainStartActivityWidget: Widget {
    public init() {}

    public var body: some WidgetConfiguration {
        ActivityConfiguration(for: RainStartActivityAttributes.self) { context in
            // Lock Screen Banner & StandBy layout
            RainActivityLockScreenView(context: context)
                .activityBackgroundTint(Color(red: 0.08, green: 0.12, blue: 0.22).opacity(0.95))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded layout
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        Image(systemName: "cloud.rain.fill")
                            .font(.title3)
                            .foregroundStyle(Color(red: 0.35, green: 0.75, blue: 1.0))

                        Text(context.attributes.city)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                            .lineLimit(1)
                    }
                    .padding(.leading, 4)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.intensity)
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.cyan.opacity(0.2))
                        .foregroundStyle(Color(red: 0.35, green: 0.75, blue: 1.0))
                        .clipShape(Capsule())
                        .padding(.trailing, 4)
                }

                DynamicIslandExpandedRegion(.center) {
                    VStack(alignment: .leading, spacing: 2) {
                        if context.state.minutesUntilRain > 0 {
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text("\(context.state.minutesUntilRain)")
                                    .font(.system(.title, design: .rounded).weight(.bold))
                                    .foregroundStyle(Color(red: 0.35, green: 0.75, blue: 1.0))
                                Text("min until rain")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(AppTheme.textPrimary)
                            }
                        } else {
                            Text("Rain in progress")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(Color(red: 0.35, green: 0.75, blue: 1.0))
                        }
                    }
                }

                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 6) {
                        Image(systemName: "clock")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textTertiary)

                        Text("Ending around ")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textTertiary)
                        +
                        Text(context.state.endTime, style: .time)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.textPrimary)

                        Spacer()

                        Image(systemName: "sparkles")
                            .font(.caption2)
                            .foregroundStyle(AppTheme.rainBlueLight)
                        Text("InsightEngine")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(AppTheme.textTertiary)
                    }
                    .padding(.horizontal, 4)
                    .padding(.top, 4)
                }
            } compactLeading: {
                // Compact leading layout
                HStack(spacing: 4) {
                    Image(systemName: "cloud.rain.fill")
                        .foregroundStyle(Color(red: 0.35, green: 0.75, blue: 1.0))
                    if context.state.minutesUntilRain > 0 {
                        Text("\(context.state.minutesUntilRain)m")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(Color(red: 0.35, green: 0.75, blue: 1.0))
                    }
                }
            } compactTrailing: {
                // Compact trailing layout
                if context.state.minutesUntilRain > 0 {
                    Text(context.state.endTime, style: .time)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(AppTheme.textSecondary)
                } else {
                    Text("Rain")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Color(red: 0.35, green: 0.75, blue: 1.0))
                }
            } minimal: {
                // Minimal layout
                Image(systemName: "cloud.rain.fill")
                    .foregroundStyle(Color(red: 0.35, green: 0.75, blue: 1.0))
            }
        }
    }
}

// MARK: - Lock Screen Layout

private struct RainActivityLockScreenView: View {
    let context: ActivityViewContext<RainStartActivityAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header: City and Intensity badge
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "cloud.rain.fill")
                        .font(.subheadline)
                        .foregroundStyle(Color(red: 0.35, green: 0.75, blue: 1.0))

                    Text(context.attributes.city)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                }

                Spacer()

                Text(context.state.intensity)
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.cyan.opacity(0.18))
                    .foregroundStyle(Color(red: 0.35, green: 0.75, blue: 1.0))
                    .clipShape(Capsule())
            }

            // Main timing message
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 2) {
                    if context.state.minutesUntilRain > 0 {
                        Text("Rain starts in \(context.state.minutesUntilRain) min")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(AppTheme.textPrimary)
                    } else {
                        Text("Rain in progress")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(Color(red: 0.35, green: 0.75, blue: 1.0))
                    }

                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textTertiary)

                        Text("Expected end around ")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textTertiary)
                        +
                        Text(context.state.endTime, style: .time)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                    }
                }

                Spacer()

                // Subtle icon badge
                ZStack {
                    Circle()
                        .fill(Color.cyan.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: context.state.minutesUntilRain > 0 ? "timer" : "drop.fill")
                        .font(.title3)
                        .foregroundStyle(Color(red: 0.35, green: 0.75, blue: 1.0))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.12, blue: 0.22),
                    Color(red: 0.04, green: 0.07, blue: 0.14)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}
