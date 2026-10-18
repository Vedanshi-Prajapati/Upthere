import Foundation

public nonisolated struct InsightEngine: Sendable {
    public init() {}

    // MARK: - 1. Rain Window
    public struct RainWindowResult: Equatable, Sendable {
        public let startDate: Date
        public let endDate: Date
        public let peakDate: Date
        public let peakProbability: Double
        public let totalPrecipitationAmount: Double

        public init(
            startDate: Date,
            endDate: Date,
            peakDate: Date,
            peakProbability: Double,
            totalPrecipitationAmount: Double
        ) {
            self.startDate = startDate
            self.endDate = endDate
            self.peakDate = peakDate
            self.peakProbability = peakProbability
            self.totalPrecipitationAmount = totalPrecipitationAmount
        }
    }

    public func rainWindow(from hourly: [HourlyWeather]) -> RainWindowResult? {
        guard !hourly.isEmpty else { return nil }
        let rainyHours = hourly.filter { $0.precipitationChance >= 0.30 }
        guard let firstRain = rainyHours.first,
              let maxRain = rainyHours.max(by: { $0.precipitationChance < $1.precipitationChance }) else {
            return nil
        }
        let lastRain = rainyHours.last ?? firstRain
        let totalAmount = rainyHours.map(\.precipitationAmount).reduce(0.0, +)

        return RainWindowResult(
            startDate: firstRain.date,
            endDate: lastRain.date,
            peakDate: maxRain.date,
            peakProbability: maxRain.precipitationChance,
            totalPrecipitationAmount: totalAmount
        )
    }

    // MARK: - 2. Temperature Trend
    public struct TemperatureTrendResult: Equatable, Sendable {
        public let minTemperature: Double
        public let maxTemperature: Double
        public let minDate: Date
        public let maxDate: Date
        public let currentTemperature: Double
        public let temperatureSwing: Double

        public init(
            minTemperature: Double,
            maxTemperature: Double,
            minDate: Date,
            maxDate: Date,
            currentTemperature: Double,
            temperatureSwing: Double
        ) {
            self.minTemperature = minTemperature
            self.maxTemperature = maxTemperature
            self.minDate = minDate
            self.maxDate = maxDate
            self.currentTemperature = currentTemperature
            self.temperatureSwing = temperatureSwing
        }
    }

    public func temperatureTrend(from hourly: [HourlyWeather]) -> TemperatureTrendResult? {
        guard hourly.count >= 2,
              let first = hourly.first,
              let minHour = hourly.min(by: { $0.temperature < $1.temperature }),
              let maxHour = hourly.max(by: { $0.temperature < $1.temperature }) else {
            return nil
        }
        let swing = maxHour.temperature - minHour.temperature
        guard swing >= 1.0 else { return nil }

        return TemperatureTrendResult(
            minTemperature: minHour.temperature,
            maxTemperature: maxHour.temperature,
            minDate: minHour.date,
            maxDate: maxHour.date,
            currentTemperature: first.temperature,
            temperatureSwing: swing
        )
    }

    // MARK: - 3. Strongest Wind
    public struct StrongestWindResult: Equatable, Sendable {
        public let currentWindSpeed: Double
        public let peakWindSpeed: Double
        public let peakGust: Double
        public let peakDate: Date

        public init(
            currentWindSpeed: Double,
            peakWindSpeed: Double,
            peakGust: Double,
            peakDate: Date
        ) {
            self.currentWindSpeed = currentWindSpeed
            self.peakWindSpeed = peakWindSpeed
            self.peakGust = peakGust
            self.peakDate = peakDate
        }
    }

    public func strongestWind(from hourly: [HourlyWeather]) -> StrongestWindResult? {
        guard let first = hourly.first else { return nil }
        guard let maxGustHour = hourly.max(by: { $0.windGust < $1.windGust }) else { return nil }
        let peakGust = maxGustHour.windGust
        let peakSpeed = hourly.map(\.windSpeed).max() ?? first.windSpeed

        // If dead calm (gust & speed <= 0), there's nothing to report
        guard peakGust > 0 || peakSpeed > 0 else { return nil }

        return StrongestWindResult(
            currentWindSpeed: first.windSpeed,
            peakWindSpeed: peakSpeed,
            peakGust: peakGust,
            peakDate: maxGustHour.date
        )
    }

    // MARK: - 4. Best Outdoor Window
    public struct BestOutdoorWindowResult: Equatable, Sendable {
        public let startDate: Date
        public let endDate: Date
        public let startIndex: Int
        public let endIndex: Int
        public let totalCount: Int
        public let averageTemperature: Double
        public let maxPrecipitationChance: Double
        public let averageWindSpeed: Double
        public let score: Double

        public init(
            startDate: Date,
            endDate: Date,
            startIndex: Int,
            endIndex: Int,
            totalCount: Int,
            averageTemperature: Double,
            maxPrecipitationChance: Double,
            averageWindSpeed: Double,
            score: Double
        ) {
            self.startDate = startDate
            self.endDate = endDate
            self.startIndex = startIndex
            self.endIndex = endIndex
            self.totalCount = totalCount
            self.averageTemperature = averageTemperature
            self.maxPrecipitationChance = maxPrecipitationChance
            self.averageWindSpeed = averageWindSpeed
            self.score = score
        }
    }

    public func bestOutdoorWindow(from hourly: [HourlyWeather]) -> BestOutdoorWindowResult? {
        guard !hourly.isEmpty else { return nil }

        func hourScore(_ hour: HourlyWeather) -> Double {
            var s = 100.0
            // Heavy penalty for rain
            s -= hour.precipitationChance * 80.0
            // Comfort temp curve (optimal 18-25 C)
            if hour.temperature < 18 {
                s -= (18 - hour.temperature) * 3.0
            } else if hour.temperature > 25 {
                s -= (hour.temperature - 25) * 3.0
            }
            // Wind penalty
            if hour.windSpeed > 20 {
                s -= (hour.windSpeed - 20) * 1.5
            }
            // UV penalty
            if hour.uvIndex > 7 {
                s -= Double(hour.uvIndex - 7) * 4.0
            }
            return s
        }

        let windowSize = min(3, hourly.count)
        var bestScore = -Double.infinity
        var bestStart = 0
        var bestEnd = max(0, windowSize - 1)

        if hourly.count >= windowSize {
            for i in 0...(hourly.count - windowSize) {
                let slice = hourly[i..<(i + windowSize)]
                let avg = slice.map { hourScore($0) }.reduce(0.0, +) / Double(windowSize)
                if avg > bestScore {
                    bestScore = avg
                    bestStart = i
                    bestEnd = i + windowSize - 1
                }
            }
        }

        let windowSlice = hourly[bestStart...bestEnd]
        let maxRain = windowSlice.map(\.precipitationChance).max() ?? 0.0

        // If even the best window has high rain (>= 70%) or poor score (< 20), nothing good to report
        if maxRain >= 0.70 || bestScore < 20.0 {
            return nil
        }

        let avgTemp = windowSlice.map(\.temperature).reduce(0.0, +) / Double(windowSlice.count)
        let avgWind = windowSlice.map(\.windSpeed).reduce(0.0, +) / Double(windowSlice.count)

        return BestOutdoorWindowResult(
            startDate: hourly[bestStart].date,
            endDate: hourly[bestEnd].date,
            startIndex: bestStart,
            endIndex: bestEnd,
            totalCount: hourly.count,
            averageTemperature: avgTemp,
            maxPrecipitationChance: maxRain,
            averageWindSpeed: avgWind,
            score: bestScore
        )
    }

    // MARK: - 5. Peak UV
    public struct PeakUVResult: Equatable, Sendable {
        public let peakUVIndex: Int
        public let peakDate: Date
        public let startDate: Date
        public let endDate: Date

        public init(
            peakUVIndex: Int,
            peakDate: Date,
            startDate: Date,
            endDate: Date
        ) {
            self.peakUVIndex = peakUVIndex
            self.peakDate = peakDate
            self.startDate = startDate
            self.endDate = endDate
        }
    }

    public func peakUV(from hourly: [HourlyWeather]) -> PeakUVResult? {
        guard !hourly.isEmpty else { return nil }
        guard let maxUVHour = hourly.max(by: { $0.uvIndex < $1.uvIndex }) else { return nil }
        let peakUV = maxUVHour.uvIndex

        // Nothing to report if UV is zero (e.g. night or dark winter)
        guard peakUV > 0 else { return nil }

        // Find range of elevated UV (within 1 of peak, > 0)
        let highUVHours = hourly.filter { $0.uvIndex >= max(1, peakUV - 1) && $0.uvIndex > 0 }
        let startDate = highUVHours.first?.date ?? maxUVHour.date
        let endDate = highUVHours.last?.date ?? maxUVHour.date

        return PeakUVResult(
            peakUVIndex: peakUV,
            peakDate: maxUVHour.date,
            startDate: startDate,
            endDate: endDate
        )
    }

    // MARK: - 6. Cloud Change
    public struct CloudChangeResult: Equatable, Sendable {
        public let changeDate: Date
        public let changeIndex: Int
        public let initialCloudCover: Double
        public let targetCloudCover: Double
        public let isClearing: Bool
        public let maxChangeRate: Double

        public init(
            changeDate: Date,
            changeIndex: Int,
            initialCloudCover: Double,
            targetCloudCover: Double,
            isClearing: Bool,
            maxChangeRate: Double
        ) {
            self.changeDate = changeDate
            self.changeIndex = changeIndex
            self.initialCloudCover = initialCloudCover
            self.targetCloudCover = targetCloudCover
            self.isClearing = isClearing
            self.maxChangeRate = maxChangeRate
        }
    }

    public func cloudChange(from hourly: [HourlyWeather]) -> CloudChangeResult? {
        guard hourly.count >= 2 else { return nil }

        let clouds = hourly.map(\.cloudCover)
        guard let minCloud = clouds.min(), let maxCloud = clouds.max() else { return nil }
        let diff = maxCloud - minCloud

        // Only report if there is a meaningful cloud shift (at least 20%)
        guard diff >= 0.20 else { return nil }

        var maxChange = 0.0
        var shiftIdx = 1
        for i in 1..<hourly.count {
            let change = abs(clouds[i] - clouds[i - 1])
            if change > maxChange {
                maxChange = change
                shiftIdx = i
            }
        }

        let firstCloud = clouds.first ?? 0.0
        let lastCloud = clouds.last ?? 0.0
        let isClearing = lastCloud < firstCloud

        let initial = isClearing ? maxCloud : firstCloud
        let target = isClearing ? minCloud : maxCloud

        return CloudChangeResult(
            changeDate: hourly[shiftIdx].date,
            changeIndex: shiftIdx,
            initialCloudCover: initial,
            targetCloudCover: target,
            isClearing: isClearing,
            maxChangeRate: maxChange
        )
    }
}
