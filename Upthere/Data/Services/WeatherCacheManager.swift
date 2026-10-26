import Foundation
import os

struct CachedWeatherRecord: Codable {
    let weather: Weather
    let savedAt: Date

    init(weather: Weather, savedAt: Date = Date()) {
        self.weather = weather
        self.savedAt = savedAt
    }

    var isFresh: Bool {
        Date().timeIntervalSince(savedAt) < 1800 // 30 minutes
    }

    var isStale: Bool {
        !isFresh && Date().timeIntervalSince(savedAt) < 86400 // Under 24 hours
    }

    var isExpired: Bool {
        Date().timeIntervalSince(savedAt) >= 86400 // 24 hours or older
    }
}

/// Lock-protected weather cache manager ensuring thread-safe cache operations across background and UI tasks.
/// Invariant: All cache reads, writes, and clearing operations are synchronized via `lock`.
final class WeatherCacheManager: @unchecked Sendable {
    static let shared = WeatherCacheManager()

    private let lock = NSLock()
    private let logger = Logger(subsystem: "com.vedanshi.upthereapp", category: "WeatherCache")
    private let defaults: UserDefaults
    private let keyPrefix = "upthere.weather.cache."
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(defaults: UserDefaults = AppGroup.defaults) {
        self.defaults = defaults
    }

    func cacheKey(for cityName: String, coordinate: (lat: Double, lon: Double)? = nil) -> String {
        let sanitized = cityName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let coordinate = coordinate {
            let latRounded = String(format: "%.2f", coordinate.lat)
            let lonRounded = String(format: "%.2f", coordinate.lon)
            return "\(keyPrefix)\(sanitized)_\(latRounded)_\(lonRounded)"
        }
        return "\(keyPrefix)city_\(sanitized)"
    }

    func save(weather: Weather, key: String) {
        lock.withLock {
            let record = CachedWeatherRecord(weather: weather, savedAt: Date())
            do {
                let data = try encoder.encode(record)
                defaults.set(data, forKey: key)
            } catch {
                logger.error("Failed to encode cache record for key \(key): \(error.localizedDescription)")
            }
        }
    }

    func load(key: String, allowExpired: Bool = false) -> CachedWeatherRecord? {
        lock.withLock {
            guard let data = defaults.data(forKey: key) else {
                // Genuinely optional: cache miss when no record has been stored for this key
                return nil
            }
            do {
                let record = try decoder.decode(CachedWeatherRecord.self, from: data)
                if record.isExpired && !allowExpired {
                    return nil
                }
                return record
            } catch {
                logger.error("Failed to decode cache record for key \(key): \(error.localizedDescription)")
                return nil
            }
        }
    }

    func clear(key: String) {
        lock.withLock {
            defaults.removeObject(forKey: key)
        }
    }

    func clearAll() {
        lock.withLock {
            let dictionary = defaults.dictionaryRepresentation()
            for k in dictionary.keys where k.hasPrefix(keyPrefix) {
                defaults.removeObject(forKey: k)
            }
        }
    }
}
