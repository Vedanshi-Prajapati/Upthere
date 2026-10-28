import Foundation
import CoreLocation
import MapKit

/// Production implementation of RouteProviding backed by MapKit's MKDirections.
public final class MapKitRouteProvider: RouteProviding, @unchecked Sendable {
    public init() {}

    public func calculateRoute(
        from origin: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D
    ) async throws -> CommuteRoute {
        let request = MKDirections.Request()
        if #available(iOS 26.0, *) {
            request.source = MKMapItem(location: CLLocation(latitude: origin.latitude, longitude: origin.longitude), address: nil)
            request.destination = MKMapItem(location: CLLocation(latitude: destination.latitude, longitude: destination.longitude), address: nil)
        } else {
            request.source = MKMapItem(placemark: MKPlacemark(coordinate: origin))
            request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destination))
        }
        request.transportType = .automobile

        let directions = MKDirections(request: request)
        let response = try await directions.calculate()

        guard let route = response.routes.first else {
            throw RouteError.noRouteFound
        }

        let pointCount = route.polyline.pointCount
        var coords = [CLLocationCoordinate2D](repeating: CLLocationCoordinate2D(), count: pointCount)
        route.polyline.getCoordinates(&coords, range: NSRange(location: 0, length: pointCount))

        return CommuteRoute(
            coordinates: coords,
            expectedTravelTime: route.expectedTravelTime,
            distance: route.distance,
            name: route.name
        )
    }
}
