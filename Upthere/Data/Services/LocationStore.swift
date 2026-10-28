import Foundation
import os

enum LocationStoreError: LocalizedError, Sendable {
    case storageUnavailable(String)

    var errorDescription: String? {
        switch self {
        case .storageUnavailable(let message):
            return message
        }
    }
}

protocol LocationStore: AnyObject, Sendable {
    func loadLocations() throws -> [SavedLocation]
    func saveLocations(_ locations: [SavedLocation]) throws
    func loadSelectedLocationId() -> UUID?
    func saveSelectedLocationId(_ id: UUID?)
}

/// Lock-protected store ensuring safe concurrent file and UserDefaults access.
/// Invariant: All disk reads, writes, and migration operations are synchronized via `lock`.
final class FileLocationStore: LocationStore, @unchecked Sendable {
    struct StoredPayload: Codable {
        var schemaVersion: Int
        var locations: [SavedLocation]
        var selectedLocationId: UUID?

        enum CodingKeys: String, CodingKey {
            case schemaVersion
            case locations
            case selectedLocationId
        }

        init(schemaVersion: Int = 1, locations: [SavedLocation], selectedLocationId: UUID?) {
            self.schemaVersion = schemaVersion
            self.locations = locations
            self.selectedLocationId = selectedLocationId
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
            self.locations = try container.decode([SavedLocation].self, forKey: .locations)
            self.selectedLocationId = try container.decodeIfPresent(UUID.self, forKey: .selectedLocationId)
        }
    }

    private enum PayloadReadResult {
        case fileMissing
        case corrupt
        case success(StoredPayload)
    }

    private let fileURL: URL?
    private let defaults: UserDefaults
    private let locationsKey = "upthere.saved_locations.list"
    private let selectedIdKey = "upthere.saved_locations.selected_id"
    private let migrationKey = "upthere.saved_locations.migrated_to_file"
    private let storeFilenameKey = "upthere.saved_locations.store_filename"
    private let lock = NSLock()
    private let logger = Logger(subsystem: "com.vedanshi.upthereapp", category: "LocationStore")

    init(
        fileURL: URL? = nil,
        defaults: UserDefaults = .standard,
        directoryProvider: (@Sendable () -> URL?)? = nil
    ) {
        self.defaults = defaults
        let isIsolatedTestDefaults = (defaults != .standard)

        if let fileURL = fileURL {
            self.fileURL = fileURL
        } else {
            // Guard against unavailable Application Support directory:
            // Refuse to fall back to temporary directory to avoid silent data loss when iOS purges /tmp.
            let appSupport: URL? = if let provider = directoryProvider {
                provider()
            } else {
                FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            }
            guard let appSupport = appSupport else {
                logger.error("Application Support directory is unavailable. Refusing temporary directory fallback to prevent data loss.")
                self.fileURL = nil
                return
            }

            let dir = appSupport.appendingPathComponent("Upthere", isDirectory: true)
            do {
                try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            } catch {
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

        if (fileURL == nil || isIsolatedTestDefaults) && self.fileURL != nil {
            migrateIfNeeded()
        }
    }

    private func migrateIfNeeded() {
        lock.lock()
        defer { lock.unlock() }

        guard let fileURL = fileURL else { return }

        // If file already exists, migration is not needed
        if FileManager.default.fileExists(atPath: fileURL.path) {
            return
        }

        // Check UserDefaults for existing data
        guard let data = defaults.data(forKey: locationsKey) else { return }
        do {
            let saved = try JSONDecoder().decode([SavedLocation].self, from: data)
            guard !saved.isEmpty else { return }
            var selectedId: UUID? = nil
            if let idString = defaults.string(forKey: selectedIdKey) {
                selectedId = UUID(uuidString: idString)
            }
            let payload = StoredPayload(schemaVersion: 1, locations: saved, selectedLocationId: selectedId)
            do {
                try writePayload(payload, to: fileURL)
                defaults.set(true, forKey: migrationKey)
            } catch {
                logger.error("Failed to write migrated location payload to \(fileURL.path): \(error.localizedDescription)")
            }
        } catch {
            logger.error("Failed to decode legacy locations for migration: \(error.localizedDescription)")
        }
    }

    func loadLocations() throws -> [SavedLocation] {
        lock.lock()
        defer { lock.unlock() }

        guard let fileURL = fileURL else {
            throw LocationStoreError.storageUnavailable("Storage is unavailable. Application Support directory could not be accessed.")
        }

        switch readPayload(from: fileURL) {
        case .success(let payload):
            return payload.locations
        case .fileMissing, .corrupt:
            return []
        }
    }

    func saveLocations(_ locations: [SavedLocation]) throws {
        lock.lock()
        defer { lock.unlock() }

        guard let fileURL = fileURL else {
            throw LocationStoreError.storageUnavailable("Storage is unavailable. Application Support directory could not be accessed.")
        }

        var payload: StoredPayload
        switch readPayload(from: fileURL) {
        case .success(let existing):
            payload = existing
        case .fileMissing, .corrupt:
            payload = StoredPayload(schemaVersion: 1, locations: [], selectedLocationId: nil)
        }
        payload.locations = locations
        try writePayload(payload, to: fileURL)
    }

    func loadSelectedLocationId() -> UUID? {
        lock.lock()
        defer { lock.unlock() }

        guard let fileURL = fileURL else { return nil }
        switch readPayload(from: fileURL) {
        case .success(let payload):
            return payload.selectedLocationId
        case .fileMissing, .corrupt:
            return nil
        }
    }

    func saveSelectedLocationId(_ id: UUID?) {
        lock.lock()
        defer { lock.unlock() }

        guard let fileURL = fileURL else { return }
        var payload: StoredPayload
        switch readPayload(from: fileURL) {
        case .success(let existing):
            payload = existing
        case .fileMissing, .corrupt:
            payload = StoredPayload(schemaVersion: 1, locations: [], selectedLocationId: nil)
        }
        payload.selectedLocationId = id
        do {
            try writePayload(payload, to: fileURL)
        } catch {
            logger.error("Failed to save selected location ID to \(fileURL.path): \(error.localizedDescription)")
        }
    }

    // MARK: - Internal File I/O

    private func readPayload(from url: URL) -> PayloadReadResult {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return .fileMissing
        }
        do {
            let data = try Data(contentsOf: url)
            let payload = try JSONDecoder().decode(StoredPayload.self, from: data)
            return .success(payload)
        } catch {
            logger.error("Failed to read or decode location payload from \(url.path): \(error.localizedDescription)")
            preserveCorruptFile(at: url)
            return .corrupt
        }
    }

    private func preserveCorruptFile(at url: URL) {
        let parentDir = url.deletingLastPathComponent()
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let corruptFilename = "saved_locations.corrupt-\(timestamp).json"
        let destinationURL = parentDir.appendingPathComponent(corruptFilename)

        do {
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            try FileManager.default.moveItem(at: url, to: destinationURL)
            logger.error(
                "Moved corrupt locations file from \(url.path) to \(destinationURL.path)"
            )
        } catch {
            logger.error(
                "Failed to preserve corrupt locations file from \(url.path) to \(destinationURL.path): \(error.localizedDescription)"
            )
        }
    }

    private func writePayload(_ payload: StoredPayload, to url: URL) throws {
        let data = try JSONEncoder().encode(payload)
        let parentDir = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }
}
