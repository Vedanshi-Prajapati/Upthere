import Foundation
import Testing
@testable import Upthere

@Suite("Location Store Tests")
struct LocationStoreTests {

    @Test("Corrupt file is preserved under corrupt timestamp name and not overwritten")
    func corruptFilePreservedAndNotOverwritten() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("test_store_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let storeURL = tempDir.appendingPathComponent("saved_locations.json")
        let corruptContent = "{\"invalid_json\": true"
        guard let corruptData = corruptContent.data(using: .utf8) else {
            Issue.record("Failed to create corrupt test data")
            return
        }
        try corruptData.write(to: storeURL)

        let store = FileLocationStore(fileURL: storeURL)
        let loaded = try store.loadLocations()
        #expect(loaded.isEmpty)

        // Verify the original bad file was moved and a corrupt backup was created
        let contents = try FileManager.default.contentsOfDirectory(atPath: tempDir.path)
        let corruptFiles = contents.filter { $0.hasPrefix("saved_locations.corrupt-") && $0.hasSuffix(".json") }
        #expect(!corruptFiles.isEmpty)

        // Writing new locations should not overwrite the preserved corrupt file
        let newLocation = SavedLocation(
            cityName: "Paris",
            regionName: "France",
            condition: "Clear",
            isCurrentLocation: false,
            latitude: 48.8566,
            longitude: 2.3522
        )
        try store.saveLocations([newLocation])

        // Verify that store now contains newLocation and corrupt backup remains intact
        let reloaded = try store.loadLocations()
        #expect(reloaded.count == 1)
        #expect(reloaded.first?.cityName == "Paris")

        let contentsAfterSave = try FileManager.default.contentsOfDirectory(atPath: tempDir.path)
        let corruptFilesAfterSave = contentsAfterSave.filter {
            $0.hasPrefix("saved_locations.corrupt-") && $0.hasSuffix(".json")
        }
        #expect(!corruptFilesAfterSave.isEmpty)

        // Check content of the preserved corrupt file
        if let preservedFile = corruptFilesAfterSave.first {
            let preservedURL = tempDir.appendingPathComponent(preservedFile)
            let preservedData = try Data(contentsOf: preservedURL)
            let preservedString = String(data: preservedData, encoding: .utf8)
            #expect(preservedString == corruptContent)
        }
    }

    @Test("Missing file still returns empty array")
    func missingFileReturnsEmptyArray() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("test_store_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let storeURL = tempDir.appendingPathComponent("saved_locations.json")
        let store = FileLocationStore(fileURL: storeURL)

        let locations = try store.loadLocations()
        #expect(locations.isEmpty)
    }

    @Test("Payload without schemaVersion still decodes with default version 1")
    func payloadWithoutSchemaVersionDecodes() throws {
        let (mockDefaults, suiteName) = makeIsolatedDefaults()
        defer { mockDefaults.removePersistentDomain(forName: suiteName) }

        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("test_store_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let storeURL = tempDir.appendingPathComponent("saved_locations.json")
        let jsonWithoutSchema = """
        {
            "locations": [
                {
                    "id": "\(UUID().uuidString)",
                    "cityName": "Tokyo",
                    "regionName": "Japan",
                    "condition": "Rain",
                    "isCurrentLocation": false,
                    "latitude": 35.6762,
                    "longitude": 139.6503
                }
            ],
            "selectedLocationId": null
        }
        """

        guard let data = jsonWithoutSchema.data(using: .utf8) else {
            Issue.record("Failed to create test JSON data")
            return
        }
        try data.write(to: storeURL)

        // 1. Test direct decode of StoredPayload
        let decodedPayload = try JSONDecoder().decode(FileLocationStore.StoredPayload.self, from: data)
        #expect(decodedPayload.schemaVersion == 1)
        #expect(decodedPayload.locations.count == 1)
        #expect(decodedPayload.locations.first?.cityName == "Tokyo")

        // 2. Test loading via FileLocationStore
        let store = FileLocationStore(fileURL: storeURL, defaults: mockDefaults)
        let loaded = try store.loadLocations()
        #expect(loaded.count == 1)
        #expect(loaded.first?.cityName == "Tokyo")
    }
}
