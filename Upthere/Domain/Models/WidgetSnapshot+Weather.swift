import Foundation

extension WidgetSnapshot {
    public init(from weather: Weather, updatedAt: Date = Date()) {
        let city = weather.cityName.isEmpty ? "UpThere" : weather.cityName
        let temp = Int(round(weather.temperature))
        let feelsLike = Int(round(weather.feelsLike))
        let high = Int(round(weather.highTemperature))
        let low = Int(round(weather.lowTemperature))
        let condition = weather.condition.isEmpty ? "Partly Cloudy" : weather.condition
        let symbolName = weather.weatherSymbolName.isEmpty ? "cloud.sun.fill" : weather.weatherSymbolName
        let rainChance = max(0, min(100, weather.chanceOfRain))

        let rainInsight: String
        if let window = weather.rainWindow, !window.title.isEmpty {
            rainInsight = "\(window.title) · \(rainChance)%"
        } else if rainChance > 0 {
            rainInsight = "\(rainChance)% chance of rain today"
        } else {
            rainInsight = "No rain expected today"
        }

        let calendar = Calendar.current
        let currentHour = calendar.component(.hour, from: updatedAt)

        let hourly: [WidgetHourlySnapshot] = weather.hourlyForecast.prefix(12).enumerated().map { idx, h in
            let itemHour = calendar.component(.hour, from: h.date)
            let timeLabel: String
            if idx == 0 || itemHour == currentHour {
                timeLabel = "Now"
            } else {
                let df = DateFormatter()
                df.locale = Locale(identifier: "en_US")
                df.dateFormat = "ha"
                timeLabel = df.string(from: h.date)
            }
            return WidgetHourlySnapshot(
                id: h.id.uuidString,
                time: timeLabel,
                temp: Int(round(h.temperature)),
                symbol: h.symbolName.isEmpty ? "cloud.sun.fill" : h.symbolName,
                rainProb: max(0, min(100, Int(round(h.precipitationChance * 100))))
            )
        }

        let daily: [WidgetDailySnapshot] = weather.dailyForecast.prefix(5).enumerated().map { idx, d in
            let dayLabel = idx == 0 ? "Today" : d.dayName
            return WidgetDailySnapshot(
                id: d.id.uuidString,
                day: dayLabel,
                symbol: d.symbolName.isEmpty ? "cloud.sun.fill" : d.symbolName,
                low: Int(round(d.lowTemperature)),
                high: Int(round(d.highTemperature)),
                rainProb: max(0, min(100, Int(round(d.precipitationProbability * 100))))
            )
        }

        self.init(
            city: city,
            temp: temp,
            feelsLike: feelsLike,
            high: high,
            low: low,
            condition: condition,
            symbolName: symbolName,
            rainChance: rainChance,
            rainInsight: rainInsight,
            hourly: hourly,
            daily: daily,
            updatedAt: updatedAt
        )
    }
}
