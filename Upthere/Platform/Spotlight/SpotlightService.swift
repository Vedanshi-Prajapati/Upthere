import Foundation
import CoreSpotlight
import UniformTypeIdentifiers
import os

@MainActor
public final class SpotlightService {
    public static let shared = SpotlightService()

    public static let weatherDomain = "com.vedanshi.upthere.weather"
    public static let locationsDomain = "com.vedanshi.upthere.locations"

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.vedanshi.upthereapp", category: "Spotlight")
    private let index = CSSearchableIndex.default()

    private init() {}

    // MARK: - Weather Indexing

    /// Indexes the current live weather into iOS Spotlight
    public func indexWeather(_ weather: Weather) {
        let tempInt = Int(round(weather.temperature))
        let highInt = Int(round(weather.highTemperature))
        let lowInt = Int(round(weather.lowTemperature))
        let rainChance = weather.chanceOfRain

        let attributeSet = CSSearchableItemAttributeSet(contentType: .content)
        attributeSet.title = "\(weather.cityName) Weather · \(tempInt)° \(weather.condition)"
        attributeSet.contentDescription = "Feels like \(Int(round(weather.feelsLike)))°. High \(highInt)°, Low \(lowInt)°. \(rainChance)% chance of rain. \(weather.description)"
        attributeSet.keywords = [
            "Weather",
            "UpThere",
            "Forecast",
            "Temperature",
            "Rain",
            "Radar",
            "Atmosphere",
            weather.cityName,
            weather.condition
        ]
        attributeSet.containerTitle = "UpThere Weather"
        attributeSet.containerDisplayName = "UpThere"

        let identifier = "weather.\(weather.cityName.lowercased().replacingOccurrences(of: " ", with: "_"))"
        let item = CSSearchableItem(
            uniqueIdentifier: identifier,
            domainIdentifier: Self.weatherDomain,
            attributeSet: attributeSet
        )
        // Keep fresh for 4 hours
        item.expirationDate = Date().addingTimeInterval(4 * 3600)

        let latStr = weather.latitude.map { "\($0)" } ?? "nil"
        let lonStr = weather.longitude.map { "\($0)" } ?? "nil"

        index.indexSearchableItems([item]) { [weak self] error in
            if let error = error {
                self?.logger.error("Failed to index weather for \(weather.cityName, privacy: .private) (lat: \(latStr, privacy: .private), lon: \(lonStr, privacy: .private)): \(error.localizedDescription)")
            } else {
                self?.logger.debug("Successfully indexed weather for \(weather.cityName, privacy: .private) (lat: \(latStr, privacy: .private), lon: \(lonStr, privacy: .private))")
            }
        }
    }

    // MARK: - Saved Locations Indexing

    /// Indexes all saved locations into iOS Spotlight for instant system search
    public func indexSavedLocations(_ locations: [SavedLocation]) {
        let items: [CSSearchableItem] = locations.map { loc in
            let attributeSet = CSSearchableItemAttributeSet(contentType: .content)
            attributeSet.title = "\(loc.cityName) Forecast"
            let subtitle = loc.regionName.isEmpty ? loc.condition : "\(loc.regionName) · \(loc.condition)"
            attributeSet.contentDescription = subtitle
            attributeSet.keywords = [
                "Weather",
                "UpThere",
                "City",
                "Forecast",
                loc.cityName,
                loc.regionName,
                loc.condition
            ]
            attributeSet.containerTitle = "UpThere Saved Locations"
            attributeSet.containerDisplayName = "UpThere"

            let id = "location.\(loc.cityName.lowercased().replacingOccurrences(of: " ", with: "_"))"
            let item = CSSearchableItem(
                uniqueIdentifier: id,
                domainIdentifier: Self.locationsDomain,
                attributeSet: attributeSet
            )
            item.expirationDate = Date().addingTimeInterval(30 * 24 * 3600)
            return item
        }

        guard !items.isEmpty else { return }

        index.indexSearchableItems(items) { [weak self] error in
            if let error = error {
                self?.logger.error("Failed to index saved locations: \(error.localizedDescription)")
            } else {
                self?.logger.debug("Successfully indexed \(locations.count) saved locations")
            }
        }
    }

    // MARK: - Removal

    public func removeWeatherIndex(for cityName: String) {
        logger.debug("Removing weather index for \(cityName, privacy: .private)")
        let id = "weather.\(cityName.lowercased().replacingOccurrences(of: " ", with: "_"))"
        index.deleteSearchableItems(withIdentifiers: [id], completionHandler: nil)
    }

    public func removeLocationIndex(for cityName: String) {
        logger.debug("Removing location index for \(cityName, privacy: .private)")
        let id = "location.\(cityName.lowercased().replacingOccurrences(of: " ", with: "_"))"
        index.deleteSearchableItems(withIdentifiers: [id], completionHandler: nil)
    }

    public func deindexAll() {
        logger.debug("De-indexing all Spotlight items")
        index.deleteAllSearchableItems(completionHandler: nil)
    }

    // MARK: - Resolution

    /// Resolves city name from Spotlight selection identifier
    public func resolveCityName(from identifier: String) -> String? {
        if identifier.hasPrefix("weather.") {
            let slug = String(identifier.dropFirst("weather.".count))
            return slug.replacingOccurrences(of: "_", with: " ").capitalized
        } else if identifier.hasPrefix("location.") {
            let slug = String(identifier.dropFirst("location.".count))
            return slug.replacingOccurrences(of: "_", with: " ").capitalized
        }
        return nil
    }
}
