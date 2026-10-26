import Foundation
import os

protocol LocationStore: AnyObject, Sendable {
    func loadLocations() throws -> [SavedLocation]
    func saveLocations(_ locations: [SavedLocation]) throws
    func loadSelectedLocationId() -> UUID?
    func saveSelectedLocationId(_ id: UUID?)
}

/// Lock-protected store ensuring safe concurrent file and UserDefaults access.
/// Invariant: All disk reads, writes, and migration operations are synchronized via `lock`.
final class FileLocationStore: LocationStore, @unchecked Sendable {
    private struct StoredPayload: Codable {
        var locations: [SavedLocation]
        var selectedLocationId: UUID?
    }

    private let fileURL: URL
    private let defaults: UserDefaults
    private let locationsKey = "upthere.saved_locations.list"
    private let selectedIdKey = "upthere.saved_locations.selected_id"
    private let migrationKey = "upthere.saved_locations.migrated_to_file"
    private let storeFilenameKey = "upthere.saved_locations.store_filename"
    private let lock = NSLock()
    private let logger = Logger(subsystem: "com.vedanshi.upthereapp", category: "LocationStore")

    init(
        fileURL: URL? = nil,
        defaults: UserDefaults = .standard
    ) {
        self.defaults = defaults
        let isIsolatedTestDefaults = (defaults != .standard)

        if let fileURL = fileURL {
            self.fileURL = fileURL
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            let dir = appSupport.appendingPathComponent("Upthere", isDirectory: true)
            do {
                try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            } catch {
                let logger = Logger(subsystem: "com.vedanshi.upthereapp", category: "LocationStore")
                logger.error("Failed to create Upthere directory at \(dir.path): \(error.localizedDescription)")
            }
            if isIsolatedTestDefaults {
                let filename: String
                if let existingName = defaults.string(forKey: storeFilenameKey) {
                    filename = existingName
                } else {
                    let newName = "saved_locations_test_\(UUID().uuidString).json"
                    defaults.set(newName, forKey: storeFilenameKey)
                    filename = newName
                }
                self.fileURL = dir.appendingPathComponent(filename)
            } else {
                self.fileURL = dir.appendingPathComponent("saved_locations.json")
            }
        }

        // Only migrate from defaults if:
        // 1) Production app: fileURL was nil && defaults was .standard, OR
        // 2) Isolated test defaults explicitly supplied: defaults != .standard
        if fileURL == nil || isIsolatedTestDefaults {
            migrateIfNeeded()
        }
    }

    private func migrateIfNeeded() {
        lock.lock()
        defer { lock.unlock() }

        // If file already exists, migration is not needed
        if FileManager.default.fileExists(atPath: fileURL.path) {
            return
        }

        // Check UserDefaults for existing data
        if let data = defaults.data(forKey: locationsKey),
           let saved = try? JSONDecoder().decode([SavedLocation].self, from: data),
           !saved.isEmpty {
            var selectedId: UUID? = nil
            if let idString = defaults.string(forKey: selectedIdKey) {
                selectedId = UUID(uuidString: idString)
            }
            let payload = StoredPayload(locations: saved, selectedLocationId: selectedId)
            do {
                try writePayload(payload)
                defaults.set(true, forKey: migrationKey)
            } catch {
                logger.error("Failed to write migrated location payload to \(self.fileURL.path): \(error.localizedDescription)")
            }
        }
    }

    func loadLocations() throws -> [SavedLocation] {
        lock.lock()
        defer { lock.unlock() }

        guard let payload = readPayload() else {
            return []
        }
        return payload.locations
    }

    func saveLocations(_ locations: [SavedLocation]) throws {
        lock.lock()
        defer { lock.unlock() }

        var payload = readPayload() ?? StoredPayload(locations: [], selectedLocationId: nil)
        payload.locations = locations
        try writePayload(payload)
    }

    func loadSelectedLocationId() -> UUID? {
        lock.lock()
        defer { lock.unlock() }

        return readPayload()?.selectedLocationId
    }

    func saveSelectedLocationId(_ id: UUID?) {
        lock.lock()
        defer { lock.unlock() }

        var payload = readPayload() ?? StoredPayload(locations: [], selectedLocationId: nil)
        payload.selectedLocationId = id
        do {
            try writePayload(payload)
        } catch {
            logger.error("Failed to save selected location ID to \(self.fileURL.path): \(error.localizedDescription)")
        }
    }

    // MARK: - Internal File I/O

    private func readPayload() -> StoredPayload? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            // Genuinely optional: file does not exist yet before first save
            return nil
        }
        do {
            let data = try Data(contentsOf: fileURL)
            return try JSONDecoder().decode(StoredPayload.self, from: data)
        } catch {
            logger.error("Failed to read or decode location payload from \(self.fileURL.path): \(error.localizedDescription)")
            return nil
        }
    }

    private func writePayload(_ payload: StoredPayload) throws {
        let data = try JSONEncoder().encode(payload)
        let parentDir = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)
        try data.write(to: fileURL, options: .atomic)
    }
}
