import Foundation
@testable import Upthere

/// Lock-protected test store for simulating disk failure.
/// Invariant: `shouldFailSave` state access is synchronized via `lock`.
final class FailingLocationStore: LocationStore, @unchecked Sendable {
    private let lock = NSLock()
    private var _shouldFailSave = false

    var shouldFailSave: Bool {
        get { lock.withLock { _shouldFailSave } }
        set { lock.withLock { _shouldFailSave = newValue } }
    }

    func loadLocations() throws -> [SavedLocation] { [SavedLocationsManager.defaultCurrentLocation] }
    func saveLocations(_ locations: [SavedLocation]) throws {
        let fail = lock.withLock { _shouldFailSave }
        if fail {
            throw NSError(domain: "TestStoreError", code: 42, userInfo: [NSLocalizedDescriptionKey: "Disk full"])
        }
    }
    func loadSelectedLocationId() -> UUID? { nil }
    func saveSelectedLocationId(_ id: UUID?) {}
}
