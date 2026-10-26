import Testing
import Foundation
import CoreLocation
import AppIntents
import SwiftUI
import WidgetKit
@testable import Upthere

@Suite("WidgetSnapshot Tests")
@MainActor
struct WidgetSnapshotTests {

    @Test("WidgetSnapshotStore saves and loads snapshot through JSON round trip")
    func widgetSnapshotStoreRoundTrip() throws {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_widget_snapshot_\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let store = WidgetSnapshotStore(fileURL: tempURL)

        let snapshot = WidgetSnapshot(
            city: "San Francisco",
            temp: 18,
            feelsLike: 17,
            high: 22,
            low: 14,
            condition: "Sunny",
            symbolName: "sun.max.fill",
            rainChance: 10,
            rainInsight: "No rain expected today",
            hourly: [
                .init(id: "h1", time: "Now", temp: 18, symbol: "sun.max.fill", rainProb: 0),
                .init(id: "h2", time: "1 PM", temp: 20, symbol: "sun.max.fill", rainProb: 5)
            ],
            daily: [
                .init(id: "d1", day: "Today", symbol: "sun.max.fill", low: 14, high: 22, rainProb: 10),
                .init(id: "d2", day: "Thu", symbol: "cloud.sun.fill", low: 13, high: 21, rainProb: 15)
            ],
            updatedAt: Date()
        )

        try store.save(snapshot)

        let loaded = store.load()
        #expect(loaded != nil)
        #expect(loaded?.city == "San Francisco")
        #expect(loaded?.temp == 18)
        #expect(loaded?.feelsLike == 17)
        #expect(loaded?.high == 22)
        #expect(loaded?.low == 14)
        #expect(loaded?.condition == "Sunny")
        #expect(loaded?.symbolName == "sun.max.fill")
        #expect(loaded?.rainChance == 10)
        #expect(loaded?.hourly.count == 2)
        #expect(loaded?.daily.count == 2)
    }


    @Test("WidgetSnapshot maps from Weather domain model accurately")
    func widgetSnapshotFromWeather() {
        let weather = Weather(
            cityName: "Tokyo",
            temperature: 24.3,
            condition: "Clear",
            highTemperature: 28.1,
            lowTemperature: 19.4,
            feelsLike: 25.0,
            weatherSymbolName: "sun.max.fill",
            chanceOfRain: 20
        )

        let snapshot = WidgetSnapshot(from: weather)
        #expect(snapshot.city == "Tokyo")
        #expect(snapshot.temp == 24)
        #expect(snapshot.high == 28)
        #expect(snapshot.low == 19)
        #expect(snapshot.feelsLike == 25)
        #expect(snapshot.condition == "Clear")
        #expect(snapshot.symbolName == "sun.max.fill")
        #expect(snapshot.rainChance == 20)
    }


    @Test("WeatherWidgetEntry displays empty state when no snapshot exists")
    func weatherWidgetEntryEmptyState() {
        let entry = WeatherWidgetEntry(from: nil)
        #expect(entry.isEmpty == true)
        #expect(entry.isStale == true)
        #expect(entry.condition == "Open UpThere to set your location")
        #expect(entry.updatedAtText == nil)
    }


    @Test("WeatherWidgetEntry displays stale state and updated timestamp when older than 3 hours")
    func weatherWidgetEntryStaleStateAfter3Hours() {
        let now = Date()
        let staleDate = now.addingTimeInterval(-3.5 * 3600) // 3.5 hours ago
        let snapshot = WidgetSnapshot(
            city: "London",
            temp: 15,
            feelsLike: 14,
            high: 18,
            low: 11,
            condition: "Rain",
            symbolName: "cloud.rain.fill",
            rainChance: 80,
            rainInsight: "Rain likely · 80%",
            hourly: [],
            daily: [],
            updatedAt: staleDate
        )

        let entry = WeatherWidgetEntry(from: snapshot, date: now)
        #expect(entry.isEmpty == false)
        #expect(entry.isStale == true)
        #expect(entry.condition == "Open UpThere to load weather")
        #expect(entry.updatedAtText?.hasPrefix("Updated ") == true)
        #expect(entry.cityName == "London")
        #expect(entry.temperature == 15)
    }


    @Test("Timeline provider: fresh fetch writes new snapshot and returns entries for next few hours")
    func timelineFreshFetchWritesSnapshot() async throws {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_provider_fresh_\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let store = WidgetSnapshotStore(fileURL: tempURL)
        let initialSnapshot = WidgetSnapshot(
            city: "San Francisco",
            latitude: 37.7749,
            longitude: -122.4194,
            temp: 15,
            feelsLike: 15,
            high: 18,
            low: 12,
            condition: "Cloudy",
            symbolName: "cloud.fill",
            rainChance: 0,
            rainInsight: "No rain expected",
            hourly: [],
            daily: [],
            updatedAt: Date().addingTimeInterval(-3600)
        )
        try store.save(initialSnapshot)

        let now = Date()
        let freshHourly: [HourlyWeather] = [
            HourlyWeather(date: now, temperature: 22, precipitationChance: 0.0, symbolName: "sun.max.fill"),
            HourlyWeather(date: now.addingTimeInterval(3600), temperature: 24, precipitationChance: 0.1, symbolName: "sun.max.fill"),
            HourlyWeather(date: now.addingTimeInterval(7200), temperature: 23, precipitationChance: 0.2, symbolName: "cloud.sun.fill")
        ]
        let freshWeather = Weather(
            cityName: "San Francisco",
            latitude: 37.7749,
            longitude: -122.4194,
            temperature: 22,
            condition: "Clear",
            highTemperature: 25,
            lowTemperature: 14,
            weatherSymbolName: "sun.max.fill",
            hourlyForecast: freshHourly
        )

        final class FakeFetcher: WidgetWeatherFetching, Sendable {
            let weather: Weather
            init(weather: Weather) { self.weather = weather }
            func fetchWeather(for location: CLLocation, cityName: String) async throws -> Weather {
                weather
            }
        }

        let fakeFetcher = FakeFetcher(weather: freshWeather)
        let provider = WeatherWidgetTimelineProvider(weatherFetcher: fakeFetcher, snapshotStore: store)

        let timeline = await provider.loadTimeline()

        // 1. Fresh fetch writes the snapshot
        let saved = store.load()
        #expect(saved != nil)
        #expect(saved?.temp == 22)
        #expect(saved?.condition == "Clear")
        #expect(saved?.city == "San Francisco")
        #expect(saved?.latitude == 37.7749)
        #expect(saved?.longitude == -122.4194)

        // 2. Returns entries for the next few hours
        #expect(timeline.entries.count >= 2)
        #expect(timeline.entries[0].temperature == 22)
        #expect(timeline.entries[0].isStale == false)
        #expect(timeline.entries[0].isEmpty == false)
    }


    @Test("Timeline provider: fetch failure falls back to saved snapshot and displays Updated timestamp")
    func timelineFailureFallsBackToStaleSnapshot() async throws {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_provider_stale_\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let store = WidgetSnapshotStore(fileURL: tempURL)
        let savedDate = Date().addingTimeInterval(-1800)
        let savedSnapshot = WidgetSnapshot(
            city: "London",
            latitude: 51.5074,
            longitude: -0.1278,
            temp: 14,
            feelsLike: 13,
            high: 17,
            low: 10,
            condition: "Rain",
            symbolName: "cloud.rain.fill",
            rainChance: 70,
            rainInsight: "Rain likely · 70%",
            hourly: [],
            daily: [],
            updatedAt: savedDate
        )
        try store.save(savedSnapshot)

        struct MockNetworkError: Error {}
        final class FailingFetcher: WidgetWeatherFetching, Sendable {
            func fetchWeather(for location: CLLocation, cityName: String) async throws -> Weather {
                throw MockNetworkError()
            }
        }

        let fakeFetcher = FailingFetcher()
        let provider = WeatherWidgetTimelineProvider(weatherFetcher: fakeFetcher, snapshotStore: store)

        let timeline = await provider.loadTimeline()

        #expect(timeline.entries.count == 1)
        let fallbackEntry = timeline.entries[0]
        #expect(fallbackEntry.cityName == "London")
        #expect(fallbackEntry.temperature == 14)
        #expect(fallbackEntry.isStale == true)
        #expect(fallbackEntry.updatedAtText?.hasPrefix("Updated ") == true)
    }


    @Test("Timeline provider: returns empty state when no snapshot exists")
    func timelineNoSnapshotReturnsEmptyState() async {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_provider_empty_\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let store = WidgetSnapshotStore(fileURL: tempURL)
        final class EmptyFetcher: WidgetWeatherFetching, Sendable {
            func fetchWeather(for location: CLLocation, cityName: String) async throws -> Weather {
                throw WeatherUnavailableError()
            }
        }

        let fakeFetcher = EmptyFetcher()
        let provider = WeatherWidgetTimelineProvider(weatherFetcher: fakeFetcher, snapshotStore: store)

        let timeline = await provider.loadTimeline()

        #expect(timeline.entries.count == 1)
        let entry = timeline.entries[0]
        #expect(entry.isEmpty == true)
        #expect(entry.condition == "Open UpThere to set your location")
        #expect(entry.rainInsight == "Open UpThere to set your location")
    }


    @Test("WeatherWidgetEntry displays fresh state when under 3 hours")
    func weatherWidgetEntryFreshState() {
        let now = Date()
        let freshDate = now.addingTimeInterval(-30 * 60) // 30 mins ago
        let snapshot = WidgetSnapshot(
            city: "Paris",
            temp: 21,
            feelsLike: 21,
            high: 25,
            low: 16,
            condition: "Partly Cloudy",
            symbolName: "cloud.sun.fill",
            rainChance: 0,
            rainInsight: "No rain expected today",
            hourly: [],
            daily: [],
            updatedAt: freshDate
        )

        let entry = WeatherWidgetEntry(from: snapshot, date: now)
        #expect(entry.isEmpty == false)
        #expect(entry.isStale == false)
        #expect(entry.condition == "Partly Cloudy")
        #expect(entry.updatedAtText == nil)
        #expect(entry.cityName == "Paris")
    }

}
