import WidgetKit
import SwiftUI

// MARK: - Models

typealias WidgetHourlyItem = WidgetHourlySnapshot
typealias WidgetDailyItem = WidgetDailySnapshot

// MARK: - Timeline Provider

struct WeatherWidgetTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> WeatherWidgetEntry {
        .preview
    }

    func getSnapshot(in context: Context, completion: @escaping (WeatherWidgetEntry) -> Void) {
        if context.isPreview {
            completion(.preview)
        } else {
            let snapshot = WidgetSnapshotStore.shared.load()
            completion(WeatherWidgetEntry(from: snapshot))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WeatherWidgetEntry>) -> Void) {
        let snapshot = WidgetSnapshotStore.shared.load()
        let entry = WeatherWidgetEntry(from: snapshot)
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

// MARK: - Main Widget

struct UpthereWeatherWidget: Widget {
    let kind: String = "UpthereWeatherWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WeatherWidgetTimelineProvider()) { entry in
            UpthereWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    WidgetSkyBackground()
                }
        }
        .configurationDisplayName("UpThere Weather")
        .description("Current weather, hourly timeline, and precipitation insights.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .systemLarge,
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline
        ])
    }
}

// MARK: - Background View

struct WidgetSkyBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.12, green: 0.35, blue: 0.75),
                Color(red: 0.04, green: 0.15, blue: 0.42)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Widget Entry View

struct UpthereWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: WeatherWidgetEntry

    var body: some View {
        switch family {
        case .accessoryCircular:
            circularAccessoryView
        case .accessoryRectangular:
            rectangularAccessoryView
        case .accessoryInline:
            inlineAccessoryView
        case .systemSmall:
            smallWidgetView
        case .systemMedium:
            mediumWidgetView
        case .systemLarge:
            largeWidgetView
        @unknown default:
            smallWidgetView
        }
    }

    // MARK: - Lock Screen Accessories

    private var circularAccessoryView: some View {
        Group {
            if entry.isEmpty {
                VStack(spacing: 2) {
                    Image(systemName: "cloud.fill")
                        .font(.caption)
                    Text("Open")
                        .font(.caption2.bold())
                }
            } else {
                Gauge(value: Double(entry.temperature), in: Double(min(entry.low, entry.temperature))...Double(max(entry.high, entry.temperature + 1))) {
                    Image(systemName: entry.symbolName)
                } currentValueLabel: {
                    Text("\(entry.temperature)°")
                        .font(.headline)
                }
                .gaugeStyle(.accessoryCircular)
            }
        }
    }

    private var rectangularAccessoryView: some View {
        Group {
            if entry.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "cloud.fill")
                        .font(.title3)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("UpThere")
                            .font(.headline)
                        Text("Open UpThere to load weather")
                            .font(.caption2)
                            .lineLimit(2)
                    }
                }
            } else if entry.isStale {
                HStack(spacing: 8) {
                    Image(systemName: entry.symbolName)
                        .font(.title3)

                    VStack(alignment: .leading, spacing: 1) {
                        Text("\(entry.cityName) · \(entry.temperature)°")
                            .font(.subheadline.bold())
                        Text("Open UpThere to load weather")
                            .font(.caption2)
                            .lineLimit(1)
                        if let updated = entry.updatedAtText {
                            Text(updated)
                                .font(.caption2)
                        }
                    }
                }
            } else {
                HStack(spacing: 8) {
                    Image(systemName: entry.symbolName)
                        .font(.title3)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(entry.cityName) · \(entry.temperature)°")
                            .font(.subheadline.bold())
                        Text(entry.condition)
                            .font(.caption2)
                        if entry.rainChance > 0 {
                            Text("Rain: \(entry.rainChance)%")
                                .font(.caption2.weight(.semibold))
                        }
                    }
                }
            }
        }
    }

    private var inlineAccessoryView: some View {
        if entry.isEmpty {
            return Text("Open UpThere to load weather")
        } else if entry.isStale {
            let updateSuffix = entry.updatedAtText.map { " · \($0)" } ?? ""
            return Text("\(entry.cityName): Open UpThere\(updateSuffix)")
        } else {
            return Text("\(entry.cityName): \(entry.temperature)° · \(entry.condition)")
        }
    }

    // MARK: - System Small

    private var smallWidgetView: some View {
        Group {
            if entry.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "cloud.sun.fill")
                        .font(.title2)
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("UpThere")
                        .font(.headline)
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("Open UpThere to load weather")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(4)
            } else if entry.isStale {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(entry.cityName)
                            .font(.headline)
                            .foregroundStyle(AppTheme.textPrimary)
                            .lineLimit(1)
                        Spacer()
                        Image(systemName: entry.symbolName)
                            .symbolRenderingMode(.multicolor)
                            .font(.title3)
                            .foregroundStyle(AppTheme.textPrimary)
                    }

                    Spacer()

                    Text("\(entry.temperature)°")
                        .font(.system(.largeTitle, design: .rounded).weight(.light))
                        .foregroundStyle(AppTheme.textPrimary)

                    Text("Open UpThere to load weather")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineLimit(1)

                    if let updated = entry.updatedAtText {
                        Text(updated)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(AppTheme.rainBlueLight)
                    }
                }
                .padding(4)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(entry.cityName)
                            .font(.headline)
                            .foregroundStyle(AppTheme.textPrimary)
                            .lineLimit(1)
                        Spacer()
                        Image(systemName: entry.symbolName)
                            .symbolRenderingMode(.multicolor)
                            .font(.title3)
                            .foregroundStyle(AppTheme.textPrimary)
                    }

                    Spacer()

                    Text("\(entry.temperature)°")
                        .font(.system(.largeTitle, design: .rounded).weight(.light))
                        .foregroundStyle(AppTheme.textPrimary)

                    Text(entry.condition)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineLimit(1)

                    HStack {
                        Text("H \(entry.high)°  L \(entry.low)°")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(AppTheme.textTertiary)

                        Spacer()

                        if entry.rainChance > 0 {
                            HStack(spacing: 2) {
                                Image(systemName: "umbrella.fill")
                                    .font(.caption2)
                                Text("\(entry.rainChance)%")
                                    .font(.caption2.weight(.semibold))
                            }
                            .foregroundStyle(AppTheme.rainBlueLight)
                        }
                    }
                }
                .padding(4)
            }
        }
    }

    // MARK: - System Medium

    private var mediumWidgetView: some View {
        Group {
            if entry.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "cloud.sun.fill")
                        .font(.title)
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("UpThere Weather")
                        .font(.headline)
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("Open UpThere to load weather")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(4)
            } else {
                HStack(spacing: 16) {
                    // Left pane: Current weather
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(entry.cityName)
                                .font(.headline)
                                .foregroundStyle(AppTheme.textPrimary)
                                .lineLimit(1)
                            Image(systemName: "location.fill")
                                .font(.caption2)
                                .foregroundStyle(AppTheme.textTertiary)
                        }

                        Text("\(entry.temperature)°")
                            .font(.system(.largeTitle, design: .rounded).weight(.light))
                            .foregroundStyle(AppTheme.textPrimary)

                        Text(entry.isStale ? "Open UpThere to load weather" : entry.condition)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(AppTheme.textSecondary)
                            .lineLimit(1)

                        if let updated = entry.updatedAtText {
                            Text(updated)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(AppTheme.rainBlueLight)
                        } else {
                            Text("H \(entry.high)°  L \(entry.low)°")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(AppTheme.textTertiary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Divider()
                        .overlay(Color.white.opacity(0.24))

                    // Right pane: 4-hour timeline strip
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 10) {
                            ForEach(entry.hourly.prefix(4)) { item in
                                VStack(spacing: 5) {
                                    Text(item.time)
                                        .font(.caption2.weight(.medium))
                                        .foregroundStyle(AppTheme.textTertiary)

                                    Image(systemName: item.symbol)
                                        .symbolRenderingMode(.multicolor)
                                        .font(.subheadline)
                                        .foregroundStyle(AppTheme.textPrimary)

                                    Text("\(item.temp)°")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(AppTheme.textPrimary)

                                    if item.rainProb > 0 {
                                        Text("\(item.rainProb)%")
                                            .font(.caption2.bold())
                                            .foregroundStyle(AppTheme.rainBlueLight)
                                    } else {
                                        Text(" ")
                                            .font(.caption2)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(4)
            }
        }
    }

    // MARK: - System Large

    private var largeWidgetView: some View {
        Group {
            if entry.isEmpty {
                VStack(spacing: 10) {
                    Spacer()
                    Image(systemName: "cloud.sun.fill")
                        .font(.largeTitle)
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("UpThere Weather")
                        .font(.title2.bold())
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("Open UpThere to load weather")
                        .font(.headline)
                        .foregroundStyle(AppTheme.textSecondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(4)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    // Header
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.cityName)
                                .font(.title3.bold())
                                .foregroundStyle(AppTheme.textPrimary)
                            Text(entry.isStale ? "Open UpThere to load weather" : "\(entry.condition) · Feels like \(entry.feelsLike)°")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                        Spacer()
                        Text("\(entry.temperature)°")
                            .font(.system(.largeTitle, design: .rounded).weight(.light))
                            .foregroundStyle(AppTheme.textPrimary)
                    }

                    // Insight pill
                    HStack(spacing: 6) {
                        Image(systemName: "umbrella.fill")
                            .font(.caption2)
                        Text(entry.rainInsight)
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(AppTheme.rainBlueLight)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.16))
                    )

                    // Hourly timeline
                    HStack(spacing: 8) {
                        ForEach(entry.hourly.prefix(5)) { item in
                            VStack(spacing: 4) {
                                Text(item.time)
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(AppTheme.textTertiary)

                                Image(systemName: item.symbol)
                                    .symbolRenderingMode(.multicolor)
                                    .font(.subheadline)
                                    .foregroundStyle(AppTheme.textPrimary)

                                Text("\(item.temp)°")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(AppTheme.textPrimary)

                                if item.rainProb > 0 {
                                    Text("\(item.rainProb)%")
                                        .font(.caption2.bold())
                                        .foregroundStyle(AppTheme.rainBlueLight)
                                } else {
                                    Text(" ")
                                        .font(.caption2)
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.white.opacity(0.08))
                    )

                    // 3-day forecast preview
                    VStack(spacing: 6) {
                        ForEach(entry.daily) { item in
                            HStack {
                                Text(item.day)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(AppTheme.textPrimary)
                                    .frame(width: 45, alignment: .leading)

                                Image(systemName: item.symbol)
                                    .symbolRenderingMode(.multicolor)
                                    .font(.subheadline)
                                    .foregroundStyle(AppTheme.textPrimary)
                                    .frame(width: 25)

                                if item.rainProb > 0 {
                                    Text("\(item.rainProb)%")
                                        .font(.caption2.bold())
                                        .foregroundStyle(AppTheme.rainBlueLight)
                                        .frame(width: 32, alignment: .leading)
                                } else {
                                    Spacer()
                                        .frame(width: 32)
                                }

                                Spacer()

                                Text("L \(item.low)°   H \(item.high)°")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                        }
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.white.opacity(0.08))
                    )
                }
                .padding(4)
            }
        }
    }
}
