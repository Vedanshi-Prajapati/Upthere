import Foundation
import WidgetKit
import os

public struct WidgetHourlySnapshot: Codable, Sendable, Identifiable, Equatable {
    public let id: String
    public let time: String
    public let temp: Int
    public let symbol: String
    public let rainProb: Int
    public let date: Date?

    public init(id: String, time: String, temp: Int, symbol: String, rainProb: Int, date: Date? = nil) {
        self.id = id
        self.time = time
        self.temp = temp
        self.symbol = symbol
        self.rainProb = rainProb
        self.date = date
    }
}

public struct WidgetDailySnapshot: Codable, Sendable, Identifiable, Equatable {
    public let id: String
    public let day: String
    public let symbol: String
    public let low: Int
    public let high: Int
    public let rainProb: Int

    public init(id: String, day: String, symbol: String, low: Int, high: Int, rainProb: Int) {
        self.id = id
        self.day = day
        self.symbol = symbol
        self.low = low
        self.high = high
        self.rainProb = rainProb
    }
}

public struct WidgetSnapshot: Codable, Sendable, Equatable {
    public let city: String
    public let latitude: Double?
    public let longitude: Double?
    public let temp: Int
    public let feelsLike: Int
    public let high: Int
    public let low: Int
    public let condition: String
    public let symbolName: String
    public let rainChance: Int
    public let rainInsight: String
    public let hourly: [WidgetHourlySnapshot]
    public let daily: [WidgetDailySnapshot]
    public let updatedAt: Date
    public let locationStatus: LocationStatus

    enum CodingKeys: String, CodingKey {
        case city, latitude, longitude, temp, feelsLike, high, low, condition, symbolName
        case rainChance, rainInsight, hourly, daily, updatedAt, locationStatus
    }

    public init(
        city: String,
        latitude: Double? = nil,
        longitude: Double? = nil,
        temp: Int,
        feelsLike: Int,
        high: Int,
        low: Int,
        condition: String,
        symbolName: String,
        rainChance: Int,
        rainInsight: String,
        hourly: [WidgetHourlySnapshot],
        daily: [WidgetDailySnapshot],
        updatedAt: Date = Date(),
        locationStatus: LocationStatus = .live
    ) {
        self.city = city
        self.latitude = latitude
        self.longitude = longitude
        self.temp = temp
        self.feelsLike = feelsLike
        self.high = high
        self.low = low
        self.condition = condition
        self.symbolName = symbolName
        self.rainChance = rainChance
        self.rainInsight = rainInsight
        self.hourly = hourly
        self.daily = daily
        self.updatedAt = updatedAt
        self.locationStatus = locationStatus
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.city = try container.decode(String.self, forKey: .city)
        self.latitude = try container.decodeIfPresent(Double.self, forKey: .latitude)
        self.longitude = try container.decodeIfPresent(Double.self, forKey: .longitude)
        self.temp = try container.decode(Int.self, forKey: .temp)
        self.feelsLike = try container.decode(Int.self, forKey: .feelsLike)
        self.high = try container.decode(Int.self, forKey: .high)
        self.low = try container.decode(Int.self, forKey: .low)
        self.condition = try container.decode(String.self, forKey: .condition)
        self.symbolName = try container.decode(String.self, forKey: .symbolName)
        self.rainChance = try container.decode(Int.self, forKey: .rainChance)
        self.rainInsight = try container.decode(String.self, forKey: .rainInsight)
        self.hourly = try container.decode([WidgetHourlySnapshot].self, forKey: .hourly)
        self.daily = try container.decode([WidgetDailySnapshot].self, forKey: .daily)
        self.updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        self.locationStatus = try container.decodeIfPresent(LocationStatus.self, forKey: .locationStatus) ?? .live
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(city, forKey: .city)
        try container.encode(latitude, forKey: .latitude)
        try container.encode(longitude, forKey: .longitude)
        try container.encode(temp, forKey: .temp)
        try container.encode(feelsLike, forKey: .feelsLike)
        try container.encode(high, forKey: .high)
        try container.encode(low, forKey: .low)
        try container.encode(condition, forKey: .condition)
        try container.encode(symbolName, forKey: .symbolName)
        try container.encode(rainChance, forKey: .rainChance)
        try container.encode(rainInsight, forKey: .rainInsight)
        try container.encode(hourly, forKey: .hourly)
        try container.encode(daily, forKey: .daily)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encode(locationStatus, forKey: .locationStatus)
    }

    /// True if this snapshot is older than 3 hours (10,800 seconds).
    public func isStale(asOf date: Date = Date()) -> Bool {
        date.timeIntervalSince(updatedAt) > 3 * 3600
    }
}

public protocol WidgetSnapshotWriting: Sendable {
    func save(_ snapshot: WidgetSnapshot) throws
    func reloadAllTimelines()
}

public final class WidgetSnapshotStore: WidgetSnapshotWriting, Sendable {
    public static let shared = WidgetSnapshotStore()
    public static let defaultFilename = "widget_snapshot.json"

    private let fileURLOverride: URL?
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(fileURL: URL? = nil) {
        self.fileURLOverride = fileURL

        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        self.encoder = enc

        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        self.decoder = dec
    }

    public var fileURL: URL? {
        if let fileURLOverride {
            return fileURLOverride
        }
        if let envPath = ProcessInfo.processInfo.environment["WIDGET_SNAPSHOT_PATH"], !envPath.isEmpty {
            return URL(fileURLWithPath: envPath)
        }
        guard let container = AppGroup.containerURL else {
            let temp = FileManager.default.temporaryDirectory
            return temp.appendingPathComponent(Self.defaultFilename)
        }
        return container.appendingPathComponent(Self.defaultFilename)
    }

    public func save(_ snapshot: WidgetSnapshot) throws {
        guard let url = fileURL else { return }
        let data = try encoder.encode(snapshot)
        try data.write(to: url, options: .atomic)
    }

    public func reloadAllTimelines() {
        WidgetCenter.shared.reloadAllTimelines()
    }

    public func load() -> WidgetSnapshot? {
        guard let url = fileURL else { return nil }
        guard FileManager.default.fileExists(atPath: url.path) else {
            // Genuinely optional: snapshot file does not exist until first weather fetch
            return nil
        }
        do {
            let data = try Data(contentsOf: url)
            return try decoder.decode(WidgetSnapshot.self, from: data)
        } catch {
            let logger = Logger(subsystem: "com.vedanshi.upthereapp", category: "WidgetSnapshot")
            logger.error("Failed to load or decode widget snapshot from \(url.path): \(error.localizedDescription)")
            return nil
        }
    }
}

// MARK: - Weather Widget Entry

public struct WeatherWidgetEntry: TimelineEntry, Sendable {
    public let date: Date
    public let cityName: String
    public let condition: String
    public let temperature: Int
    public let feelsLike: Int
    public let high: Int
    public let low: Int
    public let rainChance: Int
    public let symbolName: String
    public let rainInsight: String
    public let hourly: [WidgetHourlySnapshot]
    public let daily: [WidgetDailySnapshot]
    public let isStale: Bool
    public let isEmpty: Bool
    public let updatedAtText: String?

    public init(
        date: Date = Date(),
        cityName: String,
        condition: String,
        temperature: Int,
        feelsLike: Int,
        high: Int,
        low: Int,
        rainChance: Int,
        symbolName: String,
        rainInsight: String,
        hourly: [WidgetHourlySnapshot],
        daily: [WidgetDailySnapshot],
        isStale: Bool = false,
        isEmpty: Bool = false,
        updatedAtText: String? = nil
    ) {
        self.date = date
        self.cityName = cityName
        self.condition = condition
        self.temperature = temperature
        self.feelsLike = feelsLike
        self.high = high
        self.low = low
        self.rainChance = rainChance
        self.symbolName = symbolName
        self.rainInsight = rainInsight
        self.hourly = hourly
        self.daily = daily
        self.isStale = isStale
        self.isEmpty = isEmpty
        self.updatedAtText = updatedAtText
    }

    public static var empty: WeatherWidgetEntry {
        WeatherWidgetEntry(
            date: Date(),
            cityName: "UpThere",
            condition: "Open UpThere to set your location",
            temperature: 0,
            feelsLike: 0,
            high: 0,
            low: 0,
            rainChance: 0,
            symbolName: "cloud.fill",
            rainInsight: "Open UpThere to set your location",
            hourly: [],
            daily: [],
            isStale: true,
            isEmpty: true,
            updatedAtText: nil
        )
    }

    public init(from snapshot: WidgetSnapshot?, date: Date = Date(), isStale: Bool? = nil) {
        self.date = date
        guard let snapshot else {
            self.cityName = "UpThere"
            self.condition = "Open UpThere to set your location"
            self.temperature = 0
            self.feelsLike = 0
            self.high = 0
            self.low = 0
            self.rainChance = 0
            self.symbolName = "cloud.fill"
            self.rainInsight = "Open UpThere to set your location"
            self.hourly = []
            self.daily = []
            self.isStale = true
            self.isEmpty = true
            self.updatedAtText = nil
            return
        }

        let computedStale = isStale ?? snapshot.isStale(asOf: date)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "h:mm a"
        let formattedTime = formatter.string(from: snapshot.updatedAt)
        let staleText = "Updated \(formattedTime)"

        self.cityName = snapshot.city
        self.condition = computedStale ? "Open UpThere to load weather" : snapshot.condition
        self.temperature = snapshot.temp
        self.feelsLike = snapshot.feelsLike
        self.high = snapshot.high
        self.low = snapshot.low
        self.rainChance = snapshot.rainChance
        self.symbolName = snapshot.symbolName
        self.rainInsight = computedStale ? staleText : snapshot.rainInsight
        self.hourly = snapshot.hourly
        self.daily = snapshot.daily
        self.isStale = computedStale
        self.isEmpty = false
        self.updatedAtText = computedStale ? staleText : nil
    }

    public static var preview: WeatherWidgetEntry {
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
