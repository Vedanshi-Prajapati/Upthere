import Foundation
import CoreLocation
@testable import Upthere

final class FakeHangingGeocoder: GeocoderProtocol, Sendable {
    func reverseGeocode(location: CLLocation) async throws -> String? {
        try? await Task.sleep(nanoseconds: 100_000_000_000)
        return nil
    }
}

/// Lock-protected geocoder holding pending continuations for simulated async delays.
/// Invariant: Access to pending continuations array is synchronized via `lock`.
nonisolated final class DelayedGeocoder: GeocoderProtocol, @unchecked Sendable {
    private let lock = NSLock()
    private var continuations: [CheckedContinuation<String?, Never>] = []

    func reverseGeocode(location: CLLocation) async throws -> String? {
        await withCheckedContinuation { cont in
            self.lock.withLock {
                self.continuations.append(cont)
            }
        }
    }

    func resolve(with city: String) {
        let pending = lock.withLock { () -> [CheckedContinuation<String?, Never>] in
            let c = continuations
            continuations.removeAll()
            return c
        }
        for cont in pending {
            cont.resume(returning: city)
        }
    }

    deinit {
        let pending = lock.withLock { () -> [CheckedContinuation<String?, Never>] in
            let c = continuations
            continuations.removeAll()
            return c
        }
        for cont in pending {
            cont.resume(returning: nil)
        }
    }
}
