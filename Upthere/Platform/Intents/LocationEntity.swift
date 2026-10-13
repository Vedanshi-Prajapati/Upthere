import Foundation
import AppIntents
import CoreLocation

/// AppEntity representing a saved or current location for App Intents, Siri, and Shortcuts
public struct LocationEntity: AppEntity, Identifiable, Sendable {
    public static var defaultQuery = LocationEntityQuery()
    public static var typeDisplayRepresentation: TypeDisplayRepresentation = "Location"

    public let id: String
    public let name: String
    public let region: String
    public let latitude: Double
    public let longitude: Double

    public init(id: String, name: String, region: String, latitude: Double, longitude: Double) {
        self.id = id
        self.name = name
        self.region = region
        self.latitude = latitude
        self.longitude = longitude
    }

    public var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(name)",
            subtitle: region.isEmpty ? nil : "\(region)"
        )
    }
}

public struct LocationEntityQuery: EntityQuery, EnumerableEntityQuery, Sendable {
    public init() {}

    public func allEntities() async throws -> [LocationEntity] {
        await MainActor.run {
            let saved = SavedLocationsManager.shared.savedLocations
            var entities = saved.map {
                LocationEntity(
                    id: $0.id.uuidString,
                    name: $0.cityName,
                    region: $0.regionName,
                    latitude: $0.latitude ?? 0.0,
                    longitude: $0.longitude ?? 0.0
                )
            }

            // Always provide current location option
            let current = LocationEntity(
                id: "current",
                name: "Current Location",
                region: LocationService.shared.currentCityName,
                latitude: LocationService.shared.currentLocation?.coordinate.latitude ?? LocationService.fallbackCoordinate.coordinate.latitude,
                longitude: LocationService.shared.currentLocation?.coordinate.longitude ?? LocationService.fallbackCoordinate.coordinate.longitude
            )
            entities.insert(current, at: 0)
            return entities
        }
    }

    public func entities(for identifiers: [String]) async throws -> [LocationEntity] {
        let all = try await allEntities()
        return all.filter { identifiers.contains($0.id) }
    }

    public func suggestedEntities() async throws -> [LocationEntity] {
        try await allEntities()
    }
}
