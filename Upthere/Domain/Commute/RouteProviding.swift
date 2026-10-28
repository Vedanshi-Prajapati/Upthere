import Foundation
import CoreLocation

/// Represents a calculated commute route between an origin and destination.
public struct CommuteRoute: Sendable, Equatable {
    public let coordinates: [CLLocationCoordinate2D]
    public let expectedTravelTime: TimeInterval
    public let distance: CLLocationDistance
    public let name: String?

    public init(
        coordinates: [CLLocationCoordinate2D],
        expectedTravelTime: TimeInterval,
        distance: CLLocationDistance,
        name: String? = nil
    ) {
        self.coordinates = coordinates
        self.expectedTravelTime = expectedTravelTime
        self.distance = distance
        self.name = name
    }

    public static func == (lhs: CommuteRoute, rhs: CommuteRoute) -> Bool {
        guard lhs.expectedTravelTime == rhs.expectedTravelTime,
              lhs.distance == rhs.distance,
              lhs.name == rhs.name,
              lhs.coordinates.count == rhs.coordinates.count else {
            return false
        }
        for (c1, c2) in zip(lhs.coordinates, rhs.coordinates) {
            if c1.latitude != c2.latitude || c1.longitude != c2.longitude {
                return false
            }
        }
        return true
    }
}

/// Errors that can occur during route provision.
public enum RouteError: LocalizedError, Sendable, Equatable {
    case noRouteFound
    case invalidCoordinates

    public var errorDescription: String? {
        switch self {
        case .noRouteFound:
            return "No route could be found between the specified locations."
        case .invalidCoordinates:
            return "Invalid origin or destination coordinates."
        }
    }
}

/// Protocol abstracting route calculation to allow testing without network or MapKit.
public protocol RouteProviding: Sendable {
    func calculateRoute(
        from origin: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D
    ) async throws -> CommuteRoute
}
