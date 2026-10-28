import Foundation
import CoreLocation
@testable import Upthere

final class FakeRouteProvider: RouteProviding, @unchecked Sendable {
    var routeToReturn: CommuteRoute?
    var errorToThrow: Error?
    private(set) var callCount: Int = 0
    private(set) var lastOrigin: CLLocationCoordinate2D?
    private(set) var lastDestination: CLLocationCoordinate2D?

    init(routeToReturn: CommuteRoute? = nil, errorToThrow: Error? = nil) {
        self.routeToReturn = routeToReturn
        self.errorToThrow = errorToThrow
    }

    func calculateRoute(
        from origin: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D
    ) async throws -> CommuteRoute {
        callCount += 1
        lastOrigin = origin
        lastDestination = destination

        if let error = errorToThrow {
            throw error
        }
        if let route = routeToReturn {
            return route
        }
        return CommuteRoute(
            coordinates: [origin, destination],
            expectedTravelTime: 1800,
            distance: 10000,
            name: "Test Route"
        )
    }
}
