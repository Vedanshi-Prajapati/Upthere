import WidgetKit
import SwiftUI

// MARK: - Models

struct WidgetHourlyItem: Identifiable, Sendable {
    let id: String
    let time: String
    let temp: Int
    let symbol: String
    let rainProb: Int
}

struct WidgetDailyItem: Identifiable, Sendable {
    let id: String
    let day: String
    let symbol: String
    let low: Int
    let high: Int
    let rainProb: Int
}

struct WeatherWidgetEntry: TimelineEntry {
    let date: Date
    let cityName: String
    let condition: String
    let temperature: Int
    let feelsLike: Int
    let high: Int
    let low: Int
    let rainChance: Int
    let symbolName: String
    let rainInsight: String
    let hourly: [WidgetHourlyItem]
    let daily: [WidgetDailyItem]

    static var preview: WeatherWidgetEntry {
        WeatherWidgetEntry(
            date: Date(),
            cityName: "Ghaziabad",
            condition: "Partly Cloudy",
            temperature: 28,
            feelsLike: 30,
            high: 35,
            low: 25,
            rainChance: 65,
            symbolName: "cloud.sun.fill",
            rainInsight: "Rain likely near 4 PM · 65%",
            hourly: [
                .init(id: "1", time: "Now", temp: 28, symbol: "cloud.sun.fill", rainProb: 5),
                .init(id: "2", time: "2 PM", temp: 33, symbol: "cloud.fill", rainProb: 20),
                .init(id: "3", time: "4 PM", temp: 31, symbol: "cloud.rain.fill", rainProb: 65),
                .init(id: "4", time: "6 PM", temp: 29, symbol: "cloud.drizzle.fill", rainProb: 40),
                .init(id: "5", time: "8 PM", temp: 27, symbol: "moon.fill", rainProb: 10)
            ],
            daily: [
                .init(id: "1", day: "Today", symbol: "cloud.rain.fill", low: 25, high: 35, rainProb: 65),
                .init(id: "2", day: "Wed",   symbol: "cloud.sun.fill",  low: 24, high: 34, rainProb: 10),
                .init(id: "3", day: "Thu",   symbol: "sun.max.fill",    low: 23, high: 33, rainProb: 5)
            ]
        )
    }
}

// MARK: - Timeline Provider

struct WeatherWidgetTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> WeatherWidgetEntry {
        .preview
    }

    func getSnapshot(in context: Context, completion: @escaping (WeatherWidgetEntry) -> Void) {
        completion(.preview)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WeatherWidgetEntry>) -> Void) {
        // Attempt to load from UserDefaults shared with app
        let entry = WeatherWidgetEntry.preview
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
        Gauge(value: Double(entry.temperature), in: Double(entry.low)...Double(entry.high)) {
            Image(systemName: entry.symbolName)
        } currentValueLabel: {
            Text("\(entry.temperature)°")
                .font(.system(size: 15, weight: .bold))
        }
        .gaugeStyle(.accessoryCircular)
    }

    private var rectangularAccessoryView: some View {
        HStack(spacing: 8) {
            Image(systemName: entry.symbolName)
                .font(.system(size: 22))

            VStack(alignment: .leading, spacing: 2) {
                Text("\(entry.cityName) · \(entry.temperature)°")
                    .font(.system(size: 13, weight: .bold))
                Text(entry.condition)
                    .font(.system(size: 11))
                if entry.rainChance > 0 {
                    Text("Rain: \(entry.rainChance)%")
                        .font(.system(size: 10, weight: .semibold))
                }
            }
        }
    }

    private var inlineAccessoryView: some View {
        Text("\(entry.cityName): \(entry.temperature)° · \(entry.condition)")
    }

    // MARK: - System Small

    private var smallWidgetView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(entry.cityName)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Spacer()
                Image(systemName: entry.symbolName)
                    .symbolRenderingMode(.multicolor)
                    .font(.system(size: 22))
                    .foregroundStyle(.white)
            }

            Spacer()

            Text("\(entry.temperature)°")
                .font(.system(size: 46, weight: .thin, design: .rounded))
                .foregroundStyle(.white)

            Text(entry.condition)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.85))
                .lineLimit(1)

            HStack {
                Text("H \(entry.high)°  L \(entry.low)°")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.75))

                Spacer()

                if entry.rainChance > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "umbrella.fill")
                            .font(.system(size: 9))
                        Text("\(entry.rainChance)%")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(Color(red: 0.55, green: 0.85, blue: 1.0))
                }
            }
        }
        .padding(4)
    }

    // MARK: - System Medium

    private var mediumWidgetView: some View {
        HStack(spacing: 16) {
            // Left pane: Current weather
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(entry.cityName)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Image(systemName: "location.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.white.opacity(0.7))
                }

                Text("\(entry.temperature)°")
                    .font(.system(size: 42, weight: .thin, design: .rounded))
                    .foregroundStyle(.white)

                Text(entry.condition)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.85))
                    .lineLimit(1)

                Text("H \(entry.high)°  L \(entry.low)°")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.75))
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider()
                .overlay(Color.white.opacity(0.18))

            // Right pane: 4-hour timeline strip
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 10) {
                    ForEach(entry.hourly.prefix(4)) { item in
                        VStack(spacing: 5) {
                            Text(item.time)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(Color.white.opacity(0.75))

                            Image(systemName: item.symbol)
                                .symbolRenderingMode(.multicolor)
                                .font(.system(size: 16))
                                .foregroundStyle(.white)

                            Text("\(item.temp)°")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.white)

                            if item.rainProb > 0 {
                                Text("\(item.rainProb)%")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(Color(red: 0.55, green: 0.85, blue: 1.0))
                            } else {
                                Text(" ")
                                    .font(.system(size: 9))
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

    // MARK: - System Large

    private var largeWidgetView: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.cityName)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                    Text("\(entry.condition) · Feels like \(entry.feelsLike)°")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.8))
                }
                Spacer()
                Text("\(entry.temperature)°")
                    .font(.system(size: 40, weight: .thin, design: .rounded))
                    .foregroundStyle(.white)
            }

            // Insight pill
            HStack(spacing: 6) {
                Image(systemName: "umbrella.fill")
                    .font(.system(size: 11))
                Text(entry.rainInsight)
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(Color(red: 0.55, green: 0.85, blue: 1.0))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.12))
            )

            // Hourly timeline
            HStack(spacing: 8) {
                ForEach(entry.hourly.prefix(5)) { item in
                    VStack(spacing: 4) {
                        Text(item.time)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.75))

                        Image(systemName: item.symbol)
                            .symbolRenderingMode(.multicolor)
                            .font(.system(size: 16))
                            .foregroundStyle(.white)

                        Text("\(item.temp)°")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white)

                        if item.rainProb > 0 {
                            Text("\(item.rainProb)%")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(Color(red: 0.55, green: 0.85, blue: 1.0))
                        } else {
                            Text(" ")
                                .font(.system(size: 9))
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
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 45, alignment: .leading)

                        Image(systemName: item.symbol)
                            .symbolRenderingMode(.multicolor)
                            .font(.system(size: 13))
                            .foregroundStyle(.white)
                            .frame(width: 25)

                        if item.rainProb > 0 {
                            Text("\(item.rainProb)%")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Color(red: 0.55, green: 0.85, blue: 1.0))
                                .frame(width: 32, alignment: .leading)
                        } else {
                            Spacer()
                                .frame(width: 32)
                        }

                        Spacer()

                        Text("L \(item.low)°   H \(item.high)°")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.85))
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
