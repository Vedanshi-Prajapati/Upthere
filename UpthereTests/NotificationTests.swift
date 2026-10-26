import Testing
import Foundation
import CoreLocation
import AppIntents
import SwiftUI
import WidgetKit
@testable import Upthere

@Suite("Notification Tests")
@MainActor
struct NotificationTests {

    @Test("Severe weather alert scheduled once per alert id")
    func severeWeatherAlertScheduledOnce() async {
        let fakeScheduler = FakeNotificationScheduler()
        let now = Date()
        let alert = WeatherAlert(
            id: "tornado-alert-001",
            source: "NWS",
            title: "Tornado Warning",
            validUntil: "Until 6:00 PM",
            details: "Take shelter immediately.",
            severity: "extreme",
            expirationDate: now.addingTimeInterval(3600)
        )
        let base = MockWeatherRepository.makeGhaziabadWeather()
        let weatherWithAlert = Weather(
            cityName: "Dallas",
            locationSubtitle: "Texas",
            temperature: 24,
            condition: "Thunderstorm",
            highTemperature: 28,
            lowTemperature: 18,
            feelsLike: 24,
            weatherSymbolName: "cloud.bolt.rain.fill",
            description: "Severe storm",
            humidity: 80,
            dewPoint: 20,
            windSpeed: 45,
            windDirection: "NW",
            precipitationChance: 90,
            uvIndex: 1,
            uvDescription: "Low",
            visibility: 5,
            visibilityDescription: "Poor",
            pressure: 998,
            pressureTrend: "Falling",
            alert: alert,
            hourlyForecast: base.hourlyForecast,
            dailyForecast: base.dailyForecast,
            rainWindow: base.rainWindow,
            warmingInsight: base.warmingInsight,
            chanceOfRain: 90,
            sunrise: base.sunrise,
            sunset: base.sunset,
            fetchTimestamp: now,
            isCached: false
        )

        // First refresh: schedules the alert
        await fakeScheduler.handleWeatherRefresh(
            weather: weatherWithAlert,
            rainAlertsEnabled: false,
            severeAlertsEnabled: true,
            now: now
        )

        let severeId = "\(NotificationScheduler.severeAlertIdPrefix)tornado-alert-001"
        #expect(fakeScheduler.scheduledRequests.count == 1)
        #expect(fakeScheduler.scheduledRequests.first?.id == severeId)
        #expect(fakeScheduler.scheduledRequests.first?.title == "Tornado Warning")
        #expect(fakeScheduler.scheduledRequests.first?.fireDate == nil, "Severe alerts should be immediate")

        // Second refresh with the same alert id: should NOT schedule again
        await fakeScheduler.handleWeatherRefresh(
            weather: weatherWithAlert,
            rainAlertsEnabled: false,
            severeAlertsEnabled: true,
            now: now.addingTimeInterval(300)
        )

        #expect(fakeScheduler.scheduledRequests.count == 1, "Alert should be scheduled once per alert id")
    }


    @Test("Rain alert scheduled and rescheduled without duplication")
    func rainAlertRescheduledNotDuplicated() async {
        let fakeScheduler = FakeNotificationScheduler()
        let now = Date()
        let rainStart = now.addingTimeInterval(3600) // 1 hour from now (within 2h)
        let rainHour = HourlyWeather(
            date: rainStart,
            temperature: 16,
            precipitationChance: 0.85,
            precipitationAmount: 3.0,
            symbolName: "cloud.rain.fill"
        )

        let base = MockWeatherRepository.makeGhaziabadWeather()
        let rainWeather = Weather(
            cityName: "Seattle",
            locationSubtitle: "Washington",
            temperature: 15,
            condition: "Rain",
            highTemperature: 18,
            lowTemperature: 12,
            feelsLike: 14,
            weatherSymbolName: "cloud.rain.fill",
            description: "Rain likely",
            humidity: 90,
            dewPoint: 13,
            windSpeed: 10,
            windDirection: "W",
            precipitationChance: 85,
            uvIndex: 2,
            uvDescription: "Low",
            visibility: 8,
            visibilityDescription: "Good",
            pressure: 1012,
            pressureTrend: "Steady",
            alert: nil,
            hourlyForecast: [rainHour],
            dailyForecast: base.dailyForecast,
            rainWindow: base.rainWindow,
            warmingInsight: base.warmingInsight,
            chanceOfRain: 85,
            sunrise: base.sunrise,
            sunset: base.sunset,
            fetchTimestamp: now,
            isCached: false
        )

        // First refresh: schedules rain alert 15 minutes before rain start
        await fakeScheduler.handleWeatherRefresh(
            weather: rainWeather,
            rainAlertsEnabled: true,
            severeAlertsEnabled: false,
            now: now
        )

        let rainRequests = fakeScheduler.scheduledRequests.filter { $0.id == NotificationScheduler.rainAlertId }
        #expect(rainRequests.count == 1)
        let expectedFireDate = rainStart.addingTimeInterval(-15 * 60)
        #expect(rainRequests.first?.fireDate == expectedFireDate)

        // Second refresh 5 minutes later: cancelled and rescheduled, still exactly one request
        let secondRefreshTime = now.addingTimeInterval(300)
        await fakeScheduler.handleWeatherRefresh(
            weather: rainWeather,
            rainAlertsEnabled: true,
            severeAlertsEnabled: false,
            now: secondRefreshTime
        )

        let rainRequestsAfterSecond = fakeScheduler.scheduledRequests.filter { $0.id == NotificationScheduler.rainAlertId }
        #expect(rainRequestsAfterSecond.count == 1, "Rescheduled notification must replace previous, not duplicate")
        #expect(fakeScheduler.cancelledIds.contains(NotificationScheduler.rainAlertId), "Should cancel previous rain alert on refresh")
    }


    @Test("Rain alert cancelled when rain disappears")
    func rainAlertCancelledWhenRainDisappears() async {
        let fakeScheduler = FakeNotificationScheduler()
        let now = Date()
        let rainStart = now.addingTimeInterval(3600)
        let rainHour = HourlyWeather(
            date: rainStart,
            temperature: 16,
            precipitationChance: 0.80,
            precipitationAmount: 2.0,
            symbolName: "cloud.rain.fill"
        )
        let base = MockWeatherRepository.makeGhaziabadWeather()
        let rainWeather = Weather(
            cityName: "London",
            locationSubtitle: "UK",
            temperature: 15,
            condition: "Rain",
            highTemperature: 18,
            lowTemperature: 12,
            feelsLike: 14,
            weatherSymbolName: "cloud.rain.fill",
            description: "Rain",
            humidity: 85,
            dewPoint: 12,
            windSpeed: 10,
            windDirection: "SW",
            precipitationChance: 80,
            uvIndex: 2,
            uvDescription: "Low",
            visibility: 8,
            visibilityDescription: "Good",
            pressure: 1012,
            pressureTrend: "Steady",
            alert: nil,
            hourlyForecast: [rainHour],
            dailyForecast: base.dailyForecast,
            rainWindow: base.rainWindow,
            warmingInsight: base.warmingInsight,
            chanceOfRain: 80,
            sunrise: base.sunrise,
            sunset: base.sunset,
            fetchTimestamp: now,
            isCached: false
        )

        // Schedule initially
        await fakeScheduler.handleWeatherRefresh(
            weather: rainWeather,
            rainAlertsEnabled: true,
            severeAlertsEnabled: false,
            now: now
        )
        #expect(fakeScheduler.scheduledRequests.contains { $0.id == NotificationScheduler.rainAlertId })

        // Clear weather (no rain)
        let clearHour = HourlyWeather(
            date: rainStart,
            temperature: 18,
            precipitationChance: 0.05,
            precipitationAmount: 0.0,
            symbolName: "sun.max.fill"
        )
        let clearWeather = Weather(
            cityName: "London",
            locationSubtitle: "UK",
            temperature: 17,
            condition: "Clear",
            highTemperature: 20,
            lowTemperature: 12,
            feelsLike: 17,
            weatherSymbolName: "sun.max.fill",
            description: "Sunny",
            humidity: 45,
            dewPoint: 8,
            windSpeed: 5,
            windDirection: "W",
            precipitationChance: 5,
            uvIndex: 5,
            uvDescription: "Moderate",
            visibility: 10,
            visibilityDescription: "Clear",
            pressure: 1018,
            pressureTrend: "Rising",
            alert: nil,
            hourlyForecast: [clearHour],
            dailyForecast: base.dailyForecast,
            rainWindow: nil,
            warmingInsight: base.warmingInsight,
            chanceOfRain: 5,
            sunrise: base.sunrise,
            sunset: base.sunset,
            fetchTimestamp: now.addingTimeInterval(600),
            isCached: false
        )

        // Refresh with clear weather
        await fakeScheduler.handleWeatherRefresh(
            weather: clearWeather,
            rainAlertsEnabled: true,
            severeAlertsEnabled: false,
            now: now.addingTimeInterval(600)
        )

        #expect(!fakeScheduler.scheduledRequests.contains { $0.id == NotificationScheduler.rainAlertId }, "Rain alert should be cancelled when rain disappears")
    }


    @Test("Nothing scheduled when notification toggles are off")
    func nothingScheduledWhenTogglesAreOff() async {
        let fakeScheduler = FakeNotificationScheduler()
        let now = Date()
        let rainStart = now.addingTimeInterval(3600)
        let rainHour = HourlyWeather(
            date: rainStart,
            temperature: 16,
            precipitationChance: 0.90,
            precipitationAmount: 4.0,
            symbolName: "cloud.heavyrain.fill"
        )
        let alert = WeatherAlert(
            id: "flood-alert-002",
            source: "NWS",
            title: "Flash Flood Warning",
            validUntil: "Until 8 PM",
            details: "Move to higher ground.",
            severity: "severe",
            expirationDate: now.addingTimeInterval(7200)
        )
        let base = MockWeatherRepository.makeGhaziabadWeather()
        let rainyAlertWeather = Weather(
            cityName: "Miami",
            locationSubtitle: "Florida",
            temperature: 25,
            condition: "Heavy Rain",
            highTemperature: 28,
            lowTemperature: 22,
            feelsLike: 26,
            weatherSymbolName: "cloud.heavyrain.fill",
            description: "Stormy",
            humidity: 95,
            dewPoint: 24,
            windSpeed: 30,
            windDirection: "E",
            precipitationChance: 90,
            uvIndex: 1,
            uvDescription: "Low",
            visibility: 4,
            visibilityDescription: "Poor",
            pressure: 1002,
            pressureTrend: "Falling",
            alert: alert,
            hourlyForecast: [rainHour],
            dailyForecast: base.dailyForecast,
            rainWindow: base.rainWindow,
            warmingInsight: base.warmingInsight,
            chanceOfRain: 90,
            sunrise: base.sunrise,
            sunset: base.sunset,
            fetchTimestamp: now,
            isCached: false
        )

        // Both toggles OFF
        await fakeScheduler.handleWeatherRefresh(
            weather: rainyAlertWeather,
            rainAlertsEnabled: false,
            severeAlertsEnabled: false,
            now: now
        )

        #expect(fakeScheduler.scheduledRequests.isEmpty, "Nothing should be scheduled when toggles are off")
    }


    @Test("Permission requested only when user first turns notification toggle on and denied shows banner")
    func permissionRequestedWhenToggleTurnedOn() async {
        let (mockDefaults, suiteName) = makeIsolatedDefaults()
        defer { mockDefaults.removePersistentDomain(forName: suiteName) }

        // 1. Initial state: not determined, user denies permission
        let fakeScheduler = FakeNotificationScheduler(
            authorizationStatus: .notDetermined,
            requestAuthorizationResult: false
        )
        let vm = SettingsViewModel(defaults: mockDefaults, notificationScheduler: fakeScheduler)
        #expect(fakeScheduler.requestAuthorizationCallCount == 0, "No permission request until user turns a toggle on")
        #expect(vm.rainAlertsEnabled == false)

        // User turns toggle on
        await vm.setRainAlerts(true)
        #expect(fakeScheduler.requestAuthorizationCallCount == 1, "Permission must be requested when toggle is turned on")
        #expect(vm.notificationsDenied == true, "Denied permission must update notificationsDenied flag")
        #expect(vm.rainAlertsEnabled == false, "Toggle must remain off when permission is denied")

        // 2. User grants permission
        let grantedScheduler = FakeNotificationScheduler(
            authorizationStatus: .notDetermined,
            requestAuthorizationResult: true
        )
        let vmGranted = SettingsViewModel(defaults: mockDefaults, notificationScheduler: grantedScheduler)
        await vmGranted.setRainAlerts(true)
        #expect(grantedScheduler.requestAuthorizationCallCount == 1)
        #expect(vmGranted.notificationsDenied == false)
        #expect(vmGranted.rainAlertsEnabled == true)
        #expect(mockDefaults.bool(forKey: AppGroup.rainAlertsKey) == true)
    }


    @Test("HomeViewModel schedules rain notification on successful weather refresh")
    func homeViewModelSchedulesRainNotificationOnRefresh() async {
        let (mockDefaults, suiteName) = makeIsolatedDefaults()
        defer { mockDefaults.removePersistentDomain(forName: suiteName) }

        mockDefaults.set(true, forKey: AppGroup.rainAlertsKey)
        let fakeScheduler = FakeNotificationScheduler()

        let now = Date()
        let rainStart = now.addingTimeInterval(3600)
        let rainHour = HourlyWeather(
            date: rainStart,
            temperature: 17,
            precipitationChance: 0.9,
            precipitationAmount: 4.0,
            symbolName: "cloud.rain.fill"
        )
        let base = MockWeatherRepository.makeGhaziabadWeather()
        let rainWeather = Weather(
            cityName: base.cityName,
            locationSubtitle: base.locationSubtitle,
            temperature: base.temperature,
            condition: "Rain",
            highTemperature: base.highTemperature,
            lowTemperature: base.lowTemperature,
            feelsLike: base.feelsLike,
            weatherSymbolName: "cloud.rain.fill",
            description: base.description,
            humidity: base.humidity,
            dewPoint: base.dewPoint,
            windSpeed: base.windSpeed,
            windDirection: base.windDirection,
            precipitationChance: 90,
            uvIndex: base.uvIndex,
            uvDescription: base.uvDescription,
            visibility: base.visibility,
            visibilityDescription: base.visibilityDescription,
            pressure: base.pressure,
            pressureTrend: base.pressureTrend,
            alert: nil,
            hourlyForecast: [rainHour],
            dailyForecast: base.dailyForecast,
            rainWindow: base.rainWindow,
            warmingInsight: base.warmingInsight,
            chanceOfRain: 90,
            sunrise: base.sunrise,
            sunset: base.sunset,
            fetchTimestamp: now,
            isCached: false
        )

        let repo = MockWeatherRepository(mockWeather: rainWeather, delayNanoseconds: 0)
        let useCase = GetWeatherUseCase(repository: repo)
        let vm = HomeViewModel(
            getWeatherUseCase: useCase,
            notificationScheduler: fakeScheduler,
            defaults: mockDefaults
        )

        await vm.loadWeather()

        let rainRequests = fakeScheduler.scheduledRequests.filter { $0.id == NotificationScheduler.rainAlertId }
        #expect(rainRequests.count == 1, "HomeViewModel should trigger rain notification scheduling after successful refresh")
    }

}
