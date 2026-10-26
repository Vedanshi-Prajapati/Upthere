import Testing
import Foundation
@testable import Upthere

@Suite("Rain Activity State Tests")
struct RainActivityStateTests {

    private func makeBaseDate() -> Date {
        Date(timeIntervalSince1970: 1775000000)
    }

    private func makeRainWindow(
        startOffsetMinutes: Double,
        durationMinutes: Double,
        peakProbability: Double = 0.65,
        totalPrecipitation: Double = 3.0
    ) -> (now: Date, window: InsightEngine.RainWindowResult) {
        let now = makeBaseDate()
        let start = now.addingTimeInterval(startOffsetMinutes * 60)
        let end = start.addingTimeInterval(durationMinutes * 60)
        let peak = start.addingTimeInterval((durationMinutes / 2) * 60)

        let window = InsightEngine.RainWindowResult(
            startDate: start,
            endDate: end,
            peakDate: peak,
            peakProbability: peakProbability,
            totalPrecipitationAmount: totalPrecipitation
        )
        return (now, window)
    }

    // MARK: - 1. Minutes Remaining Tests

    @Test("Calculates positive minutes remaining when rain is upcoming")
    func testMinutesRemainingUpcomingRain() {
        let (now, window) = makeRainWindow(startOffsetMinutes: 45, durationMinutes: 60)
        let result = RainActivityStateCalculator.calculateState(rainWindow: window, now: now)

        #expect(result != nil)
        #expect(result?.status == .rainPending(minutesUntilRain: 45))
        #expect(result?.minutesUntilRain == 45)
        #expect(result?.isRaining == false)
        #expect(result?.isEnded == false)
        #expect(result?.endTime == window.endDate)
    }

    @Test("Calculates minutes remaining when rain is 10 minutes away")
    func testMinutesRemainingTenMinutes() {
        let (now, window) = makeRainWindow(startOffsetMinutes: 10, durationMinutes: 45)
        let result = RainActivityStateCalculator.calculateState(rainWindow: window, now: now)

        #expect(result != nil)
        #expect(result?.minutesUntilRain == 10)
        #expect(result?.status == .rainPending(minutesUntilRain: 10))
    }

    @Test("Detects rain within 2 hours threshold correctly")
    func testRainWithinTwoHoursBoundary() {
        // Exactly 90 minutes away (within 2 hours)
        let (now90, window90) = makeRainWindow(startOffsetMinutes: 90, durationMinutes: 60)
        #expect(RainActivityStateCalculator.isRainWithinTwoHours(rainWindow: window90, now: now90) == true)

        // Exactly 120 minutes away (2 hours boundary)
        let (now120, window120) = makeRainWindow(startOffsetMinutes: 120, durationMinutes: 60)
        #expect(RainActivityStateCalculator.isRainWithinTwoHours(rainWindow: window120, now: now120) == true)

        // 150 minutes away (> 2 hours, should be false)
        let (now150, window150) = makeRainWindow(startOffsetMinutes: 150, durationMinutes: 60)
        #expect(RainActivityStateCalculator.isRainWithinTwoHours(rainWindow: window150, now: now150) == false)
    }

    // MARK: - 2. Rain Started Tests

    @Test("Transitions to rain started when current time reaches start date")
    func testRainStartedAtStartDate() {
        let (now, window) = makeRainWindow(startOffsetMinutes: 0, durationMinutes: 60)
        let result = RainActivityStateCalculator.calculateState(rainWindow: window, now: now)

        #expect(result != nil)
        #expect(result?.status == .rainStarted)
        #expect(result?.minutesUntilRain == 0)
        #expect(result?.isRaining == true)
        #expect(result?.isEnded == false)
        #expect(result?.endTime == window.endDate)
    }

    @Test("Reports rain started during the rain window")
    func testRainStartedMidwayThroughRain() {
        // Rain started 20 minutes ago, lasts another 40 minutes
        let (now, window) = makeRainWindow(startOffsetMinutes: -20, durationMinutes: 60)
        let result = RainActivityStateCalculator.calculateState(rainWindow: window, now: now)

        #expect(result != nil)
        #expect(result?.status == .rainStarted)
        #expect(result?.minutesUntilRain == 0)
        #expect(result?.isRaining == true)
        #expect(result?.isEnded == false)
        #expect(RainActivityStateCalculator.isRainWithinTwoHours(rainWindow: window, now: now) == true)
    }

    // MARK: - 3. Rain Ended Tests

    @Test("Detects rain ended at exact end date")
    func testRainEndedAtEndDate() {
        // Rain started 60 minutes ago, duration 60 minutes (now == endDate)
        let (now, window) = makeRainWindow(startOffsetMinutes: -60, durationMinutes: 60)
        let result = RainActivityStateCalculator.calculateState(rainWindow: window, now: now)

        #expect(result != nil)
        #expect(result?.status == .rainEnded)
        #expect(result?.isEnded == true)
        #expect(result?.isRaining == false)
        #expect(RainActivityStateCalculator.isRainWithinTwoHours(rainWindow: window, now: now) == false)
    }

    @Test("Detects rain ended after end date has passed")
    func testRainEndedAfterEndDate() {
        // Rain ended 30 minutes ago
        let (now, window) = makeRainWindow(startOffsetMinutes: -90, durationMinutes: 60)
        let result = RainActivityStateCalculator.calculateState(rainWindow: window, now: now)

        #expect(result != nil)
        #expect(result?.status == .rainEnded)
        #expect(result?.isEnded == true)
        #expect(result?.isRaining == false)
    }

    @Test("Returns nil state when rain window is nil")
    func testNilRainWindowReturnsNil() {
        let result = RainActivityStateCalculator.calculateState(rainWindow: nil)
        #expect(result == nil)
        #expect(RainActivityStateCalculator.isRainWithinTwoHours(rainWindow: nil) == false)
    }

    // MARK: - 4. Intensity Classification Tests

    @Test("Classifies intensity correctly across precipitation probabilities")
    func testIntensityClassification() {
        #expect(RainActivityStateCalculator.determineIntensity(peakProbability: 0.85, totalPrecipitation: 6.0) == "Heavy rain")
        #expect(RainActivityStateCalculator.determineIntensity(peakProbability: 0.70, totalPrecipitation: 1.0) == "Heavy rain")
        #expect(RainActivityStateCalculator.determineIntensity(peakProbability: 0.55, totalPrecipitation: 2.5) == "Moderate rain")
        #expect(RainActivityStateCalculator.determineIntensity(peakProbability: 0.35, totalPrecipitation: 0.5) == "Light rain")
    }

    // MARK: - 5. ContentState Mapping Tests

    @Test("Maps calculation result to Live Activity ContentState accurately")
    func testContentStateMapping() {
        let (now, window) = makeRainWindow(startOffsetMinutes: 30, durationMinutes: 60, peakProbability: 0.75)
        let result = RainActivityStateCalculator.calculateState(rainWindow: window, now: now)

        #expect(result != nil)
        guard let result else { return }
        let contentState = result.contentState
        #expect(contentState.minutesUntilRain == 30)
        #expect(contentState.intensity == "Heavy rain")
        #expect(contentState.endTime == window.endDate)
    }
}
