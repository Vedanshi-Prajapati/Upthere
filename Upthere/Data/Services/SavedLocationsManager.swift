import Foundation
import Combine

@MainActor
public final class SavedLocationsManager: ObservableObject {
    public static let shared = SavedLocationsManager()

    private let defaults: UserDefaults
    private let locationsKey = "upthere.saved_locations.list"
    private let selectedIdKey = "upthere.saved_locations.selected_id"

    @Published public private(set) var locations: [SavedLocation] = []
    @Published public private(set) var selectedLocationId: UUID?

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    public var savedLocations: [SavedLocation] { locations }

    public var selectedLocation: SavedLocation? {
        guard let id = selectedLocationId else { return nil }
        return locations.first { $0.id == id && !$0.isCurrentLocation }
    }

    public func selectLocation(_ location: SavedLocation?) {
        if let location = location, !location.isCurrentLocation {
            self.selectedLocationId = location.id
            defaults.set(location.id.uuidString, forKey: selectedIdKey)
        } else {
            self.selectedLocationId = nil
            defaults.removeObject(forKey: selectedIdKey)
        }
    }

    public func addLocation(_ location: SavedLocation) {
        // Prevent duplicate city additions
        if !locations.contains(where: { $0.cityName.caseInsensitiveCompare(location.cityName) == .orderedSame }) {
            locations.append(location)
            save()
        }
    }

    public func removeLocation(id: UUID) {
        locations.removeAll { $0.id == id && !$0.isCurrentLocation }
        if selectedLocationId == id {
            selectedLocationId = nil
            defaults.removeObject(forKey: selectedIdKey)
        }
        save()
    }

    public func moveLocation(fromIndex: Int, toIndex: Int) {
        guard fromIndex > 0, toIndex > 0,
              fromIndex < locations.count, toIndex < locations.count else { return }
        locations.swapAt(fromIndex, toIndex)
        save()
    }

    public func updateCurrentLocationHeader(cityName: String, subtitle: String) {
        guard !locations.isEmpty, locations[0].isCurrentLocation else { return }
        locations[0] = SavedLocation(
            id: locations[0].id,
            cityName: cityName,
            regionName: subtitle,
            condition: "Live",
            isCurrentLocation: true
        )
    }

    private func load() {
        if let data = defaults.data(forKey: locationsKey),
           let saved = try? JSONDecoder().decode([SavedLocation].self, from: data),
           !saved.isEmpty {
            self.locations = saved
        } else {
            self.locations = Self.defaultLocations
            save()
        }

        if let idString = defaults.string(forKey: selectedIdKey),
           let uuid = UUID(uuidString: idString) {
            self.selectedLocationId = uuid
        }
        Task.detached(priority: .utility) { [locations] in
            SpotlightService.shared.indexSavedLocations(locations)
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(locations) {
            defaults.set(data, forKey: locationsKey)
        }
        Task.detached(priority: .utility) { [locations] in
            SpotlightService.shared.indexSavedLocations(locations)
        }
    }

    public static var defaultLocations: [SavedLocation] {
        [
            SavedLocation(cityName: "Current location", regionName: "GPS location", condition: "Live", isCurrentLocation: true),
            SavedLocation(cityName: "Sydney",    regionName: "New South Wales, Australia", condition: "--", isCurrentLocation: false, latitude: -33.8688, longitude: 151.2093),
            SavedLocation(cityName: "Cupertino", regionName: "California, USA",            condition: "--", isCurrentLocation: false, latitude: 37.3230,  longitude: -122.0322),
            SavedLocation(cityName: "London",    regionName: "United Kingdom",             condition: "--", isCurrentLocation: false, latitude: 51.5074,  longitude: -0.1278),
            SavedLocation(cityName: "Tokyo",     regionName: "Japan",                      condition: "--", isCurrentLocation: false, latitude: 35.6762,  longitude: 139.6503),
            SavedLocation(cityName: "Delhi",     regionName: "National Capital Territory", condition: "--", isCurrentLocation: false, latitude: 28.6139,  longitude: 77.2090),
        ]
    }
}
