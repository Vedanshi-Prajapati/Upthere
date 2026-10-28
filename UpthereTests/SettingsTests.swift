import Testing
import Foundation
import CoreLocation
import AppIntents
import SwiftUI
import WidgetKit
@testable import Upthere

@Suite("Settings Tests")
@MainActor
struct SettingsTests {

    // MARK: - 21. Search results distinguish cities with identical names
    @Test("Search results distinguish cities with identical names in different regions")
    func searchDistinguishesDuplicateNames() {
        let portlandOR = SavedLocation(cityName: "Portland", regionName: "Oregon, United States", condition: "Rain", isCurrentLocation: false, latitude: 45.5152, longitude: -122.6784)
        let portlandME = SavedLocation(cityName: "Portland", regionName: "Maine, United States", condition: "Snow", isCurrentLocation: false, latitude: 43.6591, longitude: -70.2568)

        #expect(portlandOR.id != portlandME.id)
        #expect(portlandOR.regionName != portlandME.regionName)
    }


    // MARK: - ToggleSevereAlertsIntent
    @Test("ToggleSevereAlertsIntent inverts severe alerts setting")
    func toggleSevereAlertsIntent() async throws {
        let initial = AppGroup.defaults.bool(forKey: AppGroup.severeAlertsKey)
        let intent = ToggleSevereAlertsIntent()
        let result = try await intent.perform()

        #expect(result.value == !initial, "Toggling severe alerts intent should invert the stored setting")

        _ = try await intent.perform()
    }


    @Test("Add location persists to LocationStore")
    func addLocationPersists() {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_locs_\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let store = FileLocationStore(fileURL: tempURL)
        let manager = SavedLocationsManager(store: store)

        let initialCount = manager.locations.count
        let berlin = SavedLocation(cityName: "Berlin", regionName: "Germany", condition: "Sunny", isCurrentLocation: false, latitude: 52.52, longitude: 13.405)
        manager.addLocation(berlin)

        #expect(manager.locations.count == initialCount + 1)
        #expect(manager.locations.contains(where: { $0.cityName == "Berlin" }))

        // Re-read with a fresh manager instance
        let manager2 = SavedLocationsManager(store: store)
        #expect(manager2.locations.contains(where: { $0.cityName == "Berlin" }))
    }


    @Test("New users start with only Current location entry")
    func newUsersStartWithOnlyCurrentLocation() {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_new_user_\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let store = FileLocationStore(fileURL: tempURL)
        let manager = SavedLocationsManager(store: store)

        #expect(manager.locations.count == 1)
        #expect(manager.locations.first?.isCurrentLocation == true)
        #expect(manager.locations.first?.cityName == "Current location")
    }


    @Test("Remove location deletes non-current location but protects Current location")
    func removeLocationProtectsCurrentLocation() {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_locs_\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let store = FileLocationStore(fileURL: tempURL)
        let manager = SavedLocationsManager(store: store)
        let testCity = SavedLocation(cityName: "Berlin", regionName: "Germany", condition: "Sunny", isCurrentLocation: false, latitude: 52.52, longitude: 13.405)
        manager.addLocation(testCity)

        guard let currentLoc = manager.locations.first(where: { $0.isCurrentLocation }),
              let nonCurrentLoc = manager.locations.first(where: { !$0.isCurrentLocation }) else {
            Issue.record("Expected current and non-current locations in manager")
            return
        }

        let initialCount = manager.locations.count

        // Attempt to remove current location: should be rejected
        manager.removeLocation(id: currentLoc.id)
        #expect(manager.locations.contains(where: { $0.id == currentLoc.id }))
        #expect(manager.locations.count == initialCount)

        // Remove non-current location: should succeed
        manager.removeLocation(id: nonCurrentLoc.id)
        #expect(!manager.locations.contains(where: { $0.id == nonCurrentLoc.id }))
        #expect(manager.locations.count == initialCount - 1)
    }


    @Test("Reorder while filtered correctly updates underlying locations while keeping Current location pinned")
    func reorderWhileFiltered() {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_locs_\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let store = FileLocationStore(fileURL: tempURL)
        let manager = SavedLocationsManager(store: store)

        let loc1 = SavedLocation(cityName: "Chicago", regionName: "Illinois, USA", condition: "--", isCurrentLocation: false, latitude: 41.8781, longitude: -87.6298)
        let loc2 = SavedLocation(cityName: "Boston", regionName: "Massachusetts, USA", condition: "--", isCurrentLocation: false, latitude: 42.3601, longitude: -71.0589)
        let loc3 = SavedLocation(cityName: "Miami", regionName: "Florida, USA", condition: "--", isCurrentLocation: false, latitude: 25.7617, longitude: -80.1918)
        let loc4 = SavedLocation(cityName: "Dallas", regionName: "Texas, USA", condition: "--", isCurrentLocation: false, latitude: 32.7767, longitude: -96.7970)

        // Reset locations
        let currentLoc = manager.locations[0]
        try? store.saveLocations([currentLoc, loc1, loc2, loc3, loc4])
        let testManager = SavedLocationsManager(store: store)

        // Filter for non-current cities with "a": [Chicago, Miami, Dallas]
        let filtered = testManager.locations.filter { !$0.isCurrentLocation && $0.cityName.localizedCaseInsensitiveContains("a") }
        #expect(filtered.count == 3)
        #expect(filtered[0].cityName == "Chicago")
        #expect(filtered[1].cityName == "Miami")
        #expect(filtered[2].cityName == "Dallas")

        // In the filtered list, move Dallas (filtered index 2) to before Miami (filtered index 1)
        testManager.moveLocation(fromOffsets: IndexSet(integer: 2), toOffset: 1, within: filtered)

        // Verify underlying locations:
        // Index 0 must remain Current location
        #expect(testManager.locations[0].isCurrentLocation)
        // Dallas should now be before Miami
        guard let dallasIdx = testManager.locations.firstIndex(where: { $0.cityName == "Dallas" }),
              let miamiIdx = testManager.locations.firstIndex(where: { $0.cityName == "Miami" }) else {
            Issue.record("Expected Dallas and Miami to be found")
            return
        }
        #expect(dallasIdx < miamiIdx)
    }


    @Test("Duplicate detection allows identical city names far apart but rejects places within 5km")
    func duplicateDetectionCoordinates() {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_locs_\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let store = FileLocationStore(fileURL: tempURL)
        let manager = SavedLocationsManager(store: store)

        // Portland, Oregon vs Portland, Maine (same name, ~4100 km apart)
        let portlandOR = SavedLocation(cityName: "Portland", regionName: "Oregon, USA", condition: "Rain", isCurrentLocation: false, latitude: 45.5152, longitude: -122.6784)
        let portlandME = SavedLocation(cityName: "Portland", regionName: "Maine, USA", condition: "Sunny", isCurrentLocation: false, latitude: 43.6615, longitude: -70.2553)

        manager.addLocation(portlandOR)
        #expect(manager.locations.contains(where: { $0.regionName == "Oregon, USA" }))

        // Adding Portland, ME with same name must be allowed
        manager.addLocation(portlandME)
        #expect(manager.locations.contains(where: { $0.regionName == "Maine, USA" }), "Same city name with distant coordinates must not be treated as duplicate")

        let countBeforeNear = manager.locations.count
        // Location very close to Portland, OR (~1.2 km away at 45.5200, -122.6820)
        let nearbyPlace = SavedLocation(cityName: "Portland Downtown", regionName: "Oregon", condition: "--", isCurrentLocation: false, latitude: 45.5200, longitude: -122.6820)
        #expect(manager.isDuplicate(nearbyPlace), "Coordinates within 5km must be detected as duplicate")

        manager.addLocation(nearbyPlace)
        #expect(manager.locations.count == countBeforeNear, "Duplicate within 5km must not be added")
    }


    @Test("One-time migration from UserDefaults to FileLocationStore")
    func userDefaultsMigration() {
        let (mockDefaults, suiteName) = makeIsolatedDefaults()
        defer { mockDefaults.removePersistentDomain(forName: suiteName) }

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_migration_\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        // Seed old UserDefaults key with custom locations
        let testLoc = SavedLocation(cityName: "Zurich", regionName: "Switzerland", condition: "Snow", isCurrentLocation: false, latitude: 47.3769, longitude: 8.5417)
        guard let encoded = try? JSONEncoder().encode([SavedLocationsManager.defaultCurrentLocation, testLoc]) else {
            Issue.record("Failed to encode locations")
            return
        }
        mockDefaults.set(encoded, forKey: "upthere.saved_locations.list")
        mockDefaults.set(testLoc.id.uuidString, forKey: "upthere.saved_locations.selected_id")

        // Initialize store with no existing file: should migrate from defaults
        let store = FileLocationStore(fileURL: tempURL, defaults: mockDefaults)
        let loaded = try? store.loadLocations()

        #expect(loaded?.contains(where: { $0.cityName == "Zurich" }) == true)
        #expect(store.loadSelectedLocationId() == testLoc.id)
        #expect(FileManager.default.fileExists(atPath: tempURL.path))
    }


    @Test("SavedLocationsManager sets saveErrorMessage when store write fails")
    func saveFailureSetsErrorMessage() {
        let failingStore = FailingLocationStore()
        let manager = SavedLocationsManager(store: failingStore)

        #expect(manager.saveErrorMessage == nil)
        failingStore.shouldFailSave = true

        let testCity = SavedLocation(cityName: "Rome", regionName: "Italy", condition: "Sunny", isCurrentLocation: false, latitude: 41.9028, longitude: 12.4964)
        manager.addLocation(testCity)

        #expect(manager.saveErrorMessage != nil)
    }

    @Test("When Application Support is unavailable, FileLocationStore does not fall back to tmp and surfaces error banner")
    func applicationSupportUnavailableShowsErrorBanner() {
        let store = FileLocationStore(defaults: .standard, directoryProvider: { nil })
        let manager = SavedLocationsManager(store: store)

        #expect(manager.saveErrorMessage != nil)
        #expect(manager.saveErrorMessage?.contains("Storage is unavailable") == true)
    }


    // MARK: - App Group Settings Migration
    @Test("App Group migration copies settings once and does not overwrite later changes")
    func appGroupSettingsMigration() {
        let (mockStandard, standardSuite) = makeIsolatedDefaults()
        defer { mockStandard.removePersistentDomain(forName: standardSuite) }

        let (mockGroup, groupSuite) = makeIsolatedDefaults()
        defer { mockGroup.removePersistentDomain(forName: groupSuite) }

        // 1. Seed standard defaults with settings data
        mockStandard.set("fahrenheit", forKey: "settings.temperatureUnit")
        mockStandard.set("mph", forKey: "settings.windSpeedUnit")
        mockStandard.set("inch", forKey: "settings.precipitationUnit")
        mockStandard.set(false, forKey: "settings.rainAlertsEnabled")
        mockStandard.set(false, forKey: "settings.severeAlertsEnabled")

        // 2. Perform migration
        AppGroup.migrateSettingsIfNeeded(standard: mockStandard, group: mockGroup)

        // 3. Verify values were copied to group suite
        #expect(mockGroup.string(forKey: "settings.temperatureUnit") == "fahrenheit")
        #expect(mockGroup.string(forKey: "settings.windSpeedUnit") == "mph")
        #expect(mockGroup.string(forKey: "settings.precipitationUnit") == "inch")
        // settings.appearanceMode is no longer migrated; app is locked to dark mode
        #expect(mockGroup.bool(forKey: "settings.rainAlertsEnabled") == false)
        #expect(mockGroup.bool(forKey: "settings.severeAlertsEnabled") == false)
        #expect(mockGroup.bool(forKey: AppGroup.migrationKey) == true)

        // 4. Update group suite values with later changes
        mockGroup.set("celsius", forKey: "settings.temperatureUnit")
        mockGroup.set("kmh", forKey: "settings.windSpeedUnit")
        mockGroup.set(true, forKey: "settings.severeAlertsEnabled")

        // Also change standard to different values to ensure standard has conflicting data
        mockStandard.set("kelvin", forKey: "settings.temperatureUnit")

        // 5. Run migration again
        AppGroup.migrateSettingsIfNeeded(standard: mockStandard, group: mockGroup)

        // 6. Verify later changes in group suite were NOT overwritten
        #expect(mockGroup.string(forKey: "settings.temperatureUnit") == "celsius")
        #expect(mockGroup.string(forKey: "settings.windSpeedUnit") == "kmh")
        #expect(mockGroup.bool(forKey: "settings.severeAlertsEnabled") == true)
    }


    @Test("AppGroup containerURL returns valid or nil URL without crash")
    func appGroupContainerURL() {
        #expect(AppGroup.identifier == "group.com.vedanshi.upthereapp")
        _ = AppGroup.containerURL
        _ = AppGroup.containerURL(forSubdirectory: "WeatherCache")
    }


    @Test("SettingsViewModel reads and writes severeAlertsKey from AppGroup")
    func settingsViewModelUsesSharedAppGroupKey() {
        let (mockDefaults, suiteName) = makeIsolatedDefaults()
        defer { mockDefaults.removePersistentDomain(forName: suiteName) }

        mockDefaults.set(false, forKey: AppGroup.severeAlertsKey)
        let vm = SettingsViewModel(defaults: mockDefaults)
        #expect(vm.severeAlertsEnabled == false)

        vm.severeAlertsEnabled = true
        #expect(mockDefaults.bool(forKey: AppGroup.severeAlertsKey) == true)
    }


    @Test("SettingsViewModel formats version string from Bundle")
    func settingsViewModelAppVersionFromBundle() {
        let (mockDefaults, suiteName) = makeIsolatedDefaults()
        defer { mockDefaults.removePersistentDomain(forName: suiteName) }

        let vm = SettingsViewModel(defaults: mockDefaults)
        let expectedShort = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let expectedBuild = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        #expect(vm.appVersion == "\(expectedShort) (\(expectedBuild))")
    }


    @Test("SettingsViewModel defaults spotlightEnabled to true and writes key on change")
    func settingsViewModelSpotlightToggle() {
        let (mockDefaults, suiteName) = makeIsolatedDefaults()
        defer { mockDefaults.removePersistentDomain(forName: suiteName) }

        let vm = SettingsViewModel(defaults: mockDefaults)
        #expect(vm.spotlightEnabled == true)

        vm.spotlightEnabled = false
        #expect(mockDefaults.bool(forKey: AppGroup.spotlightEnabledKey) == false)

        let vm2 = SettingsViewModel(defaults: mockDefaults)
        #expect(vm2.spotlightEnabled == false)
    }

}
