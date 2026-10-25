import Foundation
import AppIntents
import CoreLocation

/// AppEntity representing a saved or current location for App Intents, Siri, and Shortcuts
struct LocationEntity: AppEntity, Identifiable, Sendable {
    static let defaultQuery = LocationEntityQuery()
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Location"

    let id: String
    let name: String
    let region: String
    let latitude: Double
    let longitude: Double

    init(id: String, name: String, region: String, latitude: Double, longitude: Double) {
        self.id = id
        self.name = name
        self.region = region
        self.latitude = latitude
        self.longitude = longitude
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(name)",
            subtitle: region.isEmpty ? nil : "\(region)"
        )
    }
}

struct LocationEntityQuery: EntityQuery, EnumerableEntityQuery, Sendable {
    init() {}

    func allEntities() async throws -> [LocationEntity] {
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

    func entities(for identifiers: [String]) async throws -> [LocationEntity] {
        let all = try await allEntities()
        return all.filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [LocationEntity] {
        try await allEntities()
    }
}
