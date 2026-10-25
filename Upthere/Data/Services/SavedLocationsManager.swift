import Foundation
import Combine
import CoreLocation
import os

@MainActor
public final class SavedLocationsManager: ObservableObject {
    public static let shared = SavedLocationsManager()

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.vedanshi.upthereapp", category: "SavedLocations")
    private let store: LocationStore

    @Published public private(set) var locations: [SavedLocation] = []
    @Published public private(set) var selectedLocationId: UUID?
    @Published public var saveErrorMessage: String?

    public init(store: LocationStore? = nil, defaults: UserDefaults = .standard) {
        self.store = store ?? FileLocationStore(defaults: defaults)
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
            store.saveSelectedLocationId(location.id)
        } else {
            self.selectedLocationId = nil
            store.saveSelectedLocationId(nil)
        }
    }

    // MARK: - Duplicate Detection (within ~5 km based on coordinates)
    public func isDuplicate(_ location: SavedLocation) -> Bool {
        if location.isCurrentLocation {
            return locations.contains(where: { $0.isCurrentLocation })
        }
        guard let lat = location.latitude, let lon = location.longitude else {
            return false
        }
        let target = CLLocation(latitude: lat, longitude: lon)
        for existing in locations {
            guard !existing.isCurrentLocation,
                  let exLat = existing.latitude,
                  let exLon = existing.longitude else {
                continue
            }
            let existingLoc = CLLocation(latitude: exLat, longitude: exLon)
            if target.distance(from: existingLoc) <= 5000.0 { // within ~5 km
                return true
            }
        }
        return false
    }

    public func addLocation(_ location: SavedLocation) {
        guard !isDuplicate(location) else { return }
        locations.append(location)
        ensureCurrentLocationPinned()
        save()
    }

    public func removeLocation(id: UUID) {
        // Never remove current location
        guard let target = locations.first(where: { $0.id == id }), !target.isCurrentLocation else {
            return
        }
        locations.removeAll { $0.id == id && !$0.isCurrentLocation }
        if selectedLocationId == id {
            selectedLocationId = nil
            store.saveSelectedLocationId(nil)
        }
        ensureCurrentLocationPinned()
        save()
    }

    public func moveLocation(fromIndex: Int, toIndex: Int) {
        guard fromIndex > 0, toIndex > 0,
              fromIndex < locations.count, toIndex < locations.count,
              !locations[fromIndex].isCurrentLocation,
              !locations[toIndex].isCurrentLocation else { return }
        locations.swapAt(fromIndex, toIndex)
        ensureCurrentLocationPinned()
        save()
    }

    // MARK: - Reordering (supports normal and filtered moves)
    public func moveLocation(fromOffsets: IndexSet, toOffset: Int, within filtered: [SavedLocation]? = nil) {
        // Guard: current location at index 0 must never be moved or displaced
        guard let filtered = filtered, filtered.count != locations.count else {
            var mutableOffsets = fromOffsets
            mutableOffsets.remove(0)
            guard !mutableOffsets.isEmpty else { return }

            let safeDestination = max(1, min(locations.count, toOffset))
            locations.move(fromOffsets: mutableOffsets, toOffset: safeDestination)
            ensureCurrentLocationPinned()
            save()
            return
        }

        // Filtered move
        guard let fromFilteredIdx = fromOffsets.first, fromFilteredIdx < filtered.count else { return }
        let itemToMove = filtered[fromFilteredIdx]
        guard !itemToMove.isCurrentLocation else { return }

        guard let sourceActualIdx = locations.firstIndex(where: { $0.id == itemToMove.id }) else { return }

        let targetActualIdx: Int
        if toOffset >= filtered.count {
            guard let lastFiltered = filtered.last,
                  let lastActual = locations.firstIndex(where: { $0.id == lastFiltered.id }) else { return }
            targetActualIdx = lastActual + 1
        } else {
            let destFiltered = filtered[toOffset]
            guard let destActual = locations.firstIndex(where: { $0.id == destFiltered.id }) else { return }
            targetActualIdx = destActual
        }

        let safeTarget = max(1, min(locations.count, targetActualIdx))
        locations.remove(at: sourceActualIdx)
        let insertIdx = (safeTarget > sourceActualIdx) ? safeTarget - 1 : safeTarget
        locations.insert(itemToMove, at: max(1, min(locations.count, insertIdx)))
        ensureCurrentLocationPinned()
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
        save()
    }

    private func ensureCurrentLocationPinned() {
        if let currentIdx = locations.firstIndex(where: { $0.isCurrentLocation }) {
            if currentIdx != 0 {
                let current = locations.remove(at: currentIdx)
                locations.insert(current, at: 0)
            }
        } else {
            locations.insert(Self.defaultCurrentLocation, at: 0)
        }
    }

    private func load() {
        if let saved = try? store.loadLocations(), !saved.isEmpty {
            self.locations = saved
        } else {
            self.locations = Self.defaultLocations
            save()
        }

        ensureCurrentLocationPinned()

        if let savedId = store.loadSelectedLocationId() {
            self.selectedLocationId = savedId
        }

        if AppGroup.defaults.object(forKey: AppGroup.spotlightEnabledKey) as? Bool ?? true {
            Task.detached(priority: .utility) { [locations] in
                await SpotlightService.shared.indexSavedLocations(locations)
            }
        }
    }

    private func save() {
        do {
            try store.saveLocations(locations)
            saveErrorMessage = nil
        } catch {
            logger.error("Failed to persist saved locations: \(error.localizedDescription)")
            saveErrorMessage = "Unable to save locations changes. Please try again."
        }
        store.saveSelectedLocationId(selectedLocationId)
        if AppGroup.defaults.object(forKey: AppGroup.spotlightEnabledKey) as? Bool ?? true {
            Task.detached(priority: .utility) { [locations] in
                await SpotlightService.shared.indexSavedLocations(locations)
            }
        }
    }

    public static var defaultCurrentLocation: SavedLocation {
        SavedLocation(cityName: "Current location", regionName: "GPS location", condition: "Live", isCurrentLocation: true)
    }

    public static var defaultLocations: [SavedLocation] {
        [defaultCurrentLocation]
    }
}

private extension Array {
    mutating func move(fromOffsets offsets: IndexSet, toOffset destination: Int) {
        let sortedOffsets = offsets.sorted()
        let itemsToMove = sortedOffsets.map { self[$0] }
        for index in sortedOffsets.reversed() {
            self.remove(at: index)
        }
        let adjustedDestination = destination - offsets.filter { $0 < destination }.count
        let clampedDestination = Swift.max(0, Swift.min(self.count, adjustedDestination))
        self.insert(contentsOf: itemsToMove, at: clampedDestination)
    }
}
