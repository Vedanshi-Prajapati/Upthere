import SwiftUI

// MARK: - Hourly Precipitation Bar Chart

struct HourlyPrecipitationBarChart: View {
    let hourly: [HourlyWeather]
    let rainBlue: Color

    @Environment(\.weatherFormatter) private var weatherFormatter
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedIndex: Int?
    @State private var isDragging = false
    @State private var appeared = false

    private var items: [HourlyWeather] {
        Array(hourly.prefix(24))
    }

    private var chartSummary: String {
        guard !items.isEmpty else { return "No hourly precipitation data" }
        let peakHour = items.max(by: { $0.precipitationProbability < $1.precipitationProbability })
        let peakPct = Int(round((peakHour?.precipitationProbability ?? 0) * 100))
        if peakPct > 0, let peakHour {
            return "Peak precipitation probability of \(peakPct)% at \(peakHour.time) over \(items.count) hours"
        } else {
            return "No precipitation expected over the next \(items.count) hours"
        }
    }

    var body: some View {
        VStack(spacing: 10) {
            // Readout / indicator
            HStack {
                if let selectedIndex, items.indices.contains(selectedIndex) {
                    let item = items[selectedIndex]
                    let pct = Int(round(item.precipitationProbability * 100))
                    let precipAmount = weatherFormatter.precipitation(item.precipitationAmount)
                    HStack(spacing: 6) {
                        Text(item.time)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                        Text("•")
                            .foregroundStyle(AppTheme.textTertiary)
                        Text("\(pct)% chance")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(rainBlue)
                        if item.precipitationAmount > 0 {
                            Text("(\(precipAmount))")
                                .font(.caption)
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                    }
                } else {
                    let peakHour = items.max(by: { $0.precipitationProbability < $1.precipitationProbability })
                    let peakPct = Int(round((peakHour?.precipitationProbability ?? 0) * 100))
                    if peakPct > 0, let peakHour {
                        Text("Peak: \(peakHour.time) (\(peakPct)%)")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(rainBlue)
                    } else {
                        Text("No rain expected")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }
                Spacer()
                Text("Drag across hours")
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textTertiary)
            }
            .frame(height: 18)

            // Bars area
            GeometryReader { geo in
                let count = max(1, items.count)
                let spacing: CGFloat = 3
                let totalSpacing = CGFloat(count - 1) * spacing
                let barWidth = max(4, (geo.size.width - totalSpacing) / CGFloat(count))

                ZStack(alignment: .bottomLeading) {
                    HStack(alignment: .bottom, spacing: spacing) {
                        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                            let pct = item.precipitationProbability
                            let isSelected = selectedIndex == index

                            VStack(spacing: 0) {
                                Spacer()
                                RoundedRectangle(cornerRadius: 3, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: isSelected
                                                ? [Color.white, rainBlue]
                                                : (pct > 0.05
                                                    ? [rainBlue.opacity(0.95), rainBlue.opacity(0.4)]
                                                    : [Color.white.opacity(0.10)]),
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .frame(
                                        width: barWidth,
                                        height: appeared ? max(4, pct * geo.size.height) : 4
                                    )
                                    .overlay(
                                        Group {
                                            if isSelected {
                                                RoundedRectangle(cornerRadius: 3, style: .continuous)
                                                    .stroke(Color.white, lineWidth: 1)
                                            }
                                        }
                                    )
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                        }
                    }
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            guard !items.isEmpty else { return }
                            let rawFraction = value.location.x / geo.size.width
                            let clamped = max(0, min(1, rawFraction))
                            let newIndex = min(items.count - 1, max(0, Int(round(clamped * CGFloat(items.count - 1)))))
                            if selectedIndex != newIndex {
                                selectedIndex = newIndex
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            }
                            isDragging = true
                        }
                        .onEnded { _ in
                            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.3)) {
                                isDragging = false
                                selectedIndex = nil
                            }
                        }
                )
            }
            .frame(height: 85)
            .onAppear {
                withAnimation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.7)) {
                    appeared = true
                }
            }

            // Time markers along bottom
            timeLabels
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Hourly precipitation timeline")
        .accessibilityValue(chartSummary)
    }

    private var timeLabels: some View {
        HStack {
            if let first = items.first {
                Text(first.time)
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if items.count > 6 {
                let q1 = items[items.count / 4]
                Text(q1.time)
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            if items.count > 2 {
                let mid = items[items.count / 2]
                Text(mid.time)
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            if items.count > 6 {
                let q3 = items[3 * items.count / 4]
                Text(q3.time)
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            if let last = items.last, items.count > 1 {
                Text(last.time)
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .font(.caption2)
        .foregroundStyle(AppTheme.textSecondary)
    }
}

// MARK: - Daily Precipitation Bar Chart

extension ForecastView {
    struct PrecipitationBarChart: View {
        let days: [DailyWeather]
        let rainBlue: Color

        private var chartSummary: String {
            guard !days.isEmpty else { return "No precipitation data available" }
            let peakDay = days.max(by: { $0.precipitationProbability < $1.precipitationProbability })
            let peakPct = Int(round((peakDay?.precipitationProbability ?? 0) * 100))
            if peakPct > 0, let peakDay {
                return "7-day precipitation forecast. Highest chance is \(peakPct)% on \(peakDay.dayName)."
            } else {
                return "7-day precipitation forecast. No rain expected this week."
            }
        }

        var body: some View {
            GeometryReader { geo in
                let barWidth = max(8, (geo.size.width - CGFloat(days.count - 1) * 8) / CGFloat(days.count))
                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(days) { day in
                        PrecipBar(
                            day: day,
                            barWidth: barWidth,
                            rainBlue: rainBlue
                        )
                    }
                }
            }
            .frame(height: 120)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Precipitation forecast by day")
            .accessibilityValue(chartSummary)
        }
    }

    struct PrecipBar: View {
        let day: DailyWeather
        let barWidth: CGFloat
        let rainBlue: Color

        @Environment(\.accessibilityReduceMotion) private var reduceMotion
        @State private var appeared = false

        private var pct: Double { day.precipitationProbability }           // 0–1
        private var label: String { "\(Int(round(pct * 100)))%" }
        private var shortDay: String { String(day.dayName.prefix(3)) }

        var body: some View {
            VStack(spacing: 4) {
                // Percentage label above bar
                Text(pct > 0.05 ? label : "")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(rainBlue)
                    .frame(height: 14)

                // Bar itself
                GeometryReader { geo in
                    VStack(spacing: 0) {
                        Spacer()
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: pct > 0.05
                                        ? [rainBlue.opacity(0.9), rainBlue.opacity(0.4)]
                                        : [Color.white.opacity(0.08)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(height: appeared ? max(4, pct * geo.size.height) : 4)
                            .animation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.7).delay(Double(day.dayName.hashValue % 5) * 0.05), value: appeared)
                    }
                }

                // Day label
                Text(shortDay)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .onAppear { appeared = true }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(day.dayName): \(label) chance of rain")
        }
    }
}
