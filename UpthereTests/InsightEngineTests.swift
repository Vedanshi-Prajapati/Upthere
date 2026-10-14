import Testing
import Foundation
@testable import Upthere

@Suite("InsightEngine Tests")
struct InsightEngineTests {
    let engine = InsightEngine()

    // MARK: - Fixture Generators

    private func makeBaseDate() -> Date {
        Date(timeIntervalSince1970: 1775000000) // Deterministic epoch
    }

    /// Fixture 1: Clear Day
    /// Sunny, high UV midday, warm temp curve, light breeze, 0% rain, steady 0% clouds.
    private func makeClearDayFixture() -> [HourlyWeather] {
        let baseDate = makeBaseDate()
        return (0..<24).map { i in
            let date = baseDate.addingTimeInterval(Double(i) * 3600)
            let isDay = (6...19).contains(i)
            // Midday peak UV, cooler morning/night
            let uv: Int
            switch i {
            case 11...14: uv = 9
            case 9...10, 15...16: uv = 6
            case 7...8, 17...18: uv = 2
            default: uv = 0
            }
            let temp = 18.0 + 12.0 * sin(Double(i - 6) / 18.0 * .pi)
            return HourlyWeather(
                date: date,
                temperature: temp,
                feelsLike: temp + 1.0,
                precipitationChance: 0.0,
                precipitationAmount: 0.0,
                windSpeed: 10.0 + Double(i % 3),
                windGust: 14.0 + Double(i % 3),
                uvIndex: uv,
                cloudCover: 0.05,
                symbolName: isDay ? "sun.max.fill" : "moon.clear.fill",
                isDaylight: isDay
            )
        }
    }

    /// Fixture 2: Rainy Day
    /// Clouds high, rain window peaking in the afternoon with notable accumulation.
    private func makeRainyDayFixture() -> [HourlyWeather] {
        let baseDate = makeBaseDate()
        return (0..<24).map { i in
            let date = baseDate.addingTimeInterval(Double(i) * 3600)
            let isRainyWindow = (13...17).contains(i)
            let precipChance: Double
            let precipAmount: Double
            if isRainyWindow {
                precipChance = i == 15 ? 0.85 : 0.60
                precipAmount = i == 15 ? 6.5 : 2.5
            } else {
                precipChance = 0.10
                precipAmount = 0.0
            }
            return HourlyWeather(
                date: date,
                temperature: 20.0,
                feelsLike: 20.0,
                precipitationChance: precipChance,
                precipitationAmount: precipAmount,
                windSpeed: 18.0,
                windGust: 25.0,
                uvIndex: isRainyWindow ? 1 : 3,
                cloudCover: isRainyWindow ? 0.95 : 0.60,
                symbolName: isRainyWindow ? "cloud.rain.fill" : "cloud.fill",
                isDaylight: (6...19).contains(i)
            )
        }
    }

    /// Fixture 3: Storm Night
    /// Nighttime, severe gusts, gale sustained winds, heavy downpour, 0 UV index.
    private func makeStormNightFixture() -> [HourlyWeather] {
        let baseDate = makeBaseDate()
        return (0..<8).map { i in
            let date = baseDate.addingTimeInterval(Double(i) * 3600)
            return HourlyWeather(
                date: date,
                temperature: 15.0,
                feelsLike: 11.0,
                precipitationChance: 0.95,
                precipitationAmount: 12.0,
                windSpeed: 55.0 + Double(i * 2),
                windGust: 85.0 + Double(i * 3),
                uvIndex: 0,
                cloudCover: 1.0,
                symbolName: "cloud.bolt.rain.fill",
                isDaylight: false
            )
        }
    }

    /// Fixture 4: All-Day Overcast
    /// 100% cloud cover unbroken for 24 hours, completely steady sky, no rain.
    private func makeAllDayOvercastFixture() -> [HourlyWeather] {
        let baseDate = makeBaseDate()
        return (0..<24).map { i in
            let date = baseDate.addingTimeInterval(Double(i) * 3600)
            return HourlyWeather(
                date: date,
                temperature: 17.0,
                feelsLike: 17.0,
                precipitationChance: 0.05,
                precipitationAmount: 0.0,
                windSpeed: 8.0,
                windGust: 10.0,
                uvIndex: 1,
                cloudCover: 1.0,
                symbolName: "smoke.fill",
                isDaylight: (6...19).contains(i)
            )
        }
    }

    /// Fixture 5: Polar Day with No Sunset
    /// 24 hours of daylight (isDaylight: true), midnight sun, sub-zero / near-zero temps, steady low UV.
    private func makePolarDayFixture() -> [HourlyWeather] {
        let baseDate = makeBaseDate()
        return (0..<24).map { i in
            let date = baseDate.addingTimeInterval(Double(i) * 3600)
            let temp = -4.0 + 5.0 * sin(Double(i) / 24.0 * 2.0 * .pi)
            return HourlyWeather(
                date: date,
                temperature: temp,
                feelsLike: temp - 3.0,
                precipitationChance: 0.0,
                precipitationAmount: 0.0,
                windSpeed: 12.0,
                windGust: 16.0,
                uvIndex: 2,
                cloudCover: 0.20,
                symbolName: "sun.max.fill",
                isDaylight: true
            )
        }
    }

    // MARK: - Test 1: Clear Day Fixture
    @Test("Clear day fixture identifies high UV and outdoor window while reporting nil for rain and steady clouds")
    func clearDayInsights() {
        let hourly = makeClearDayFixture()

        // 1. Rain window: nothing to report
        let rain = engine.rainWindow(from: hourly)
        #expect(rain == nil, "Clear day should not produce a rain window")

        // 2. Temperature trend: reports temperature swing
        let trend = engine.temperatureTrend(from: hourly)
        #expect(trend != nil)
        #expect((trend?.temperatureSwing ?? 0) >= 5.0)

        // 3. Strongest wind
        let wind = engine.strongestWind(from: hourly)
        #expect(wind != nil)
        #expect((wind?.peakGust ?? 0) > 10.0)

        // 4. Best outdoor window
        let outdoor = engine.bestOutdoorWindow(from: hourly)
        #expect(outdoor != nil)
        #expect(outdoor?.maxPrecipitationChance == 0.0)

        // 5. Peak UV
        let uv = engine.peakUV(from: hourly)
        #expect(uv != nil)
        #expect(uv?.peakUVIndex == 9)

        // 6. Cloud change: steady 5% clouds produces nil
        let cloud = engine.cloudChange(from: hourly)
        #expect(cloud == nil, "Steady clear sky has no cloud change to report")
    }

    // MARK: - Test 2: Rainy Day Fixture
    @Test("Rainy day fixture identifies rain window and peak precipitation hour")
    func rainyDayInsights() {
        let hourly = makeRainyDayFixture()

        // 1. Rain window
        let rain = engine.rainWindow(from: hourly)
        #expect(rain != nil)
        #expect(rain?.peakProbability == 0.85)
        #expect((rain?.totalPrecipitationAmount ?? 0) > 10.0)

        // 2. Cloud change
        let cloud = engine.cloudChange(from: hourly)
        #expect(cloud != nil, "Clouds increase significantly during rain event")
    }

    // MARK: - Test 3: Storm Night Fixture
    @Test("Storm night fixture identifies high wind gusts and rain, reports nil for UV and outdoor window")
    func stormNightInsights() {
        let hourly = makeStormNightFixture()

        // 1. Peak UV should be nil at night
        let uv = engine.peakUV(from: hourly)
        #expect(uv == nil, "UV index must be nil during storm at night")

        // 2. Strongest wind
        let wind = engine.strongestWind(from: hourly)
        #expect(wind != nil)
        #expect((wind?.peakGust ?? 0) >= 85.0)

        // 3. Rain window
        let rain = engine.rainWindow(from: hourly)
        #expect(rain != nil)
        #expect(rain?.peakProbability == 0.95)

        // 4. Best outdoor window should be nil during severe storm
        let outdoor = engine.bestOutdoorWindow(from: hourly)
        #expect(outdoor == nil, "No outdoor window should be recommended during a severe storm night")
    }

    // MARK: - Test 4: All-Day Overcast Fixture
    @Test("All-day overcast fixture reports nil for cloud changes and rain window")
    func allDayOvercastInsights() {
        let hourly = makeAllDayOvercastFixture()

        // 1. Cloud change is nil because sky is consistently 100% overcast
        let cloud = engine.cloudChange(from: hourly)
        #expect(cloud == nil, "Unbroken 100% overcast sky has no cloud change to report")

        // 2. Rain window is nil (dry overcast)
        let rain = engine.rainWindow(from: hourly)
        #expect(rain == nil, "Dry overcast has no rain window")

        // 3. Peak UV is low but non-zero
        let uv = engine.peakUV(from: hourly)
        #expect(uv?.peakUVIndex == 1)
    }

    // MARK: - Test 5: Polar Day with No Sunset Fixture
    @Test("Polar day fixture confirms 24 hours daylight and continuous daylight UV")
    func polarDayInsights() {
        let hourly = makePolarDayFixture()

        #expect(hourly.count == 24)
        #expect(hourly.allSatisfy { $0.isDaylight }, "Polar day must have isDaylight true for all hours")

        // 1. Peak UV is reported
        let uv = engine.peakUV(from: hourly)
        #expect(uv != nil)
        #expect(uv?.peakUVIndex == 2)

        // 2. Temperature trend
        let trend = engine.temperatureTrend(from: hourly)
        #expect(trend != nil)
        #expect((trend?.temperatureSwing ?? 0) > 4.0)

        // 3. Rain window is nil
        let rain = engine.rainWindow(from: hourly)
        #expect(rain == nil)
    }

    // MARK: - Test 6: Empty Forecast Fixture
    @Test("Empty forecast fixture returns nil for all insight functions")
    func emptyForecastInsights() {
        let hourly: [HourlyWeather] = []

        #expect(engine.rainWindow(from: hourly) == nil)
        #expect(engine.temperatureTrend(from: hourly) == nil)
        #expect(engine.strongestWind(from: hourly) == nil)
        #expect(engine.bestOutdoorWindow(from: hourly) == nil)
        #expect(engine.peakUV(from: hourly) == nil)
        #expect(engine.cloudChange(from: hourly) == nil)
    }
}
