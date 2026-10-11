import Foundation

public struct CachedWeatherRecord: Codable {
    public let weather: Weather
    public let savedAt: Date

    public init(weather: Weather, savedAt: Date = Date()) {
        self.weather = weather
        self.savedAt = savedAt
    }

    public var isFresh: Bool {
        Date().timeIntervalSince(savedAt) < 1800 // 30 minutes
    }

    public var isStale: Bool {
        !isFresh && Date().timeIntervalSince(savedAt) < 86400 // Under 24 hours
    }

    public var isExpired: Bool {
        Date().timeIntervalSince(savedAt) >= 86400 // 24 hours or older
    }
}

public final class WeatherCacheManager: @unchecked Sendable {
    public static let shared = WeatherCacheManager()

    private let defaults: UserDefaults
    private let keyPrefix = "upthere.weather.cache."
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func cacheKey(for cityName: String, coordinate: (lat: Double, lon: Double)? = nil) -> String {
        let sanitized = cityName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let coordinate = coordinate {
            let latRounded = String(format: "%.2f", coordinate.lat)
            let lonRounded = String(format: "%.2f", coordinate.lon)
            return "\(keyPrefix)\(sanitized)_\(latRounded)_\(lonRounded)"
        }
        return "\(keyPrefix)city_\(sanitized)"
    }

    public func save(weather: Weather, key: String) {
        let record = CachedWeatherRecord(weather: weather, savedAt: Date())
        if let data = try? encoder.encode(record) {
            defaults.set(data, forKey: key)
        }
    }

    public func load(key: String, allowExpired: Bool = false) -> CachedWeatherRecord? {
        guard let data = defaults.data(forKey: key),
              let record = try? decoder.decode(CachedWeatherRecord.self, from: data) else {
            return nil
        }
        if record.isExpired && !allowExpired {
            return nil
        }
        return record
    }

    public func clear(key: String) {
        defaults.removeObject(forKey: key)
    }

    public func clearAll() {
        let dictionary = defaults.dictionaryRepresentation()
        for k in dictionary.keys where k.hasPrefix(keyPrefix) {
            defaults.removeObject(forKey: k)
        }
    }
}
