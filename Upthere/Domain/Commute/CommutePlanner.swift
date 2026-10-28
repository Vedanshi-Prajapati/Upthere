import Foundation
import CoreLocation

/// A sampled point along a commute route with its estimated arrival time.
public struct RoutePoint: Sendable, Equatable {
    public let coordinate: CLLocationCoordinate2D
    public let eta: Date

    public init(coordinate: CLLocationCoordinate2D, eta: Date) {
        self.coordinate = coordinate
        self.eta = eta
    }

    public static func == (lhs: RoutePoint, rhs: RoutePoint) -> Bool {
        lhs.coordinate.latitude == rhs.coordinate.latitude &&
        lhs.coordinate.longitude == rhs.coordinate.longitude &&
        lhs.eta == rhs.eta
    }
}

/// A sampled point along a commute route with its estimated arrival time and relative progress fraction (0.0 to 1.0).
public struct CommuteSample: Sendable, Equatable {
    public let coordinate: CLLocationCoordinate2D
    public let eta: Date
    public let fraction: Double

    public var point: RoutePoint {
        RoutePoint(coordinate: coordinate, eta: eta)
    }

    public init(coordinate: CLLocationCoordinate2D, eta: Date, fraction: Double) {
        self.coordinate = coordinate
        self.eta = eta
        self.fraction = fraction
    }

    public init(point: RoutePoint, fraction: Double) {
        self.coordinate = point.coordinate
        self.eta = point.eta
        self.fraction = fraction
    }

    public static func == (lhs: CommuteSample, rhs: CommuteSample) -> Bool {
        lhs.coordinate.latitude == rhs.coordinate.latitude &&
        lhs.coordinate.longitude == rhs.coordinate.longitude &&
        lhs.eta == rhs.eta &&
        lhs.fraction == rhs.fraction
    }
}

/// Samples a polyline evenly by distance with ETAs and progress fractions.
/// Handles zero-length routes, single-point routes, and repeated points safely without division by zero.
public func sampleRoute(
    route: [CLLocationCoordinate2D],
    travelTime: TimeInterval,
    departure: Date,
    count: Int = 4
) -> [CommuteSample] {
    guard count > 0, !route.isEmpty else {
        return []
    }

    if count == 1 {
        return [CommuteSample(coordinate: route[0], eta: departure, fraction: 0.0)]
    }

    if route.count == 1 {
        return (0..<count).map { _ in
            CommuteSample(coordinate: route[0], eta: departure, fraction: 0.0)
        }
    }

    // Compute cumulative segment distances along polyline
    var segmentDistances: [CLLocationDistance] = []
    segmentDistances.reserveCapacity(route.count - 1)
    var cumulativeDistances: [CLLocationDistance] = [0.0]
    cumulativeDistances.reserveCapacity(route.count)

    var totalDistance: CLLocationDistance = 0.0
    for i in 0..<(route.count - 1) {
        let pA = CLLocation(latitude: route[i].latitude, longitude: route[i].longitude)
        let pB = CLLocation(latitude: route[i + 1].latitude, longitude: route[i + 1].longitude)
        let d = pA.distance(from: pB)
        segmentDistances.append(d)
        totalDistance += d
        cumulativeDistances.append(totalDistance)
    }

    // Handles repeated points or zero-length route without dividing by zero
    if totalDistance <= 0.0 {
        return (0..<count).map { _ in
            CommuteSample(coordinate: route[0], eta: departure, fraction: 0.0)
        }
    }

    var samples: [CommuteSample] = []
    samples.reserveCapacity(count)

    var currentSegmentIndex = 0

    for k in 0..<count {
        let fraction = Double(k) / Double(count - 1)
        let targetDistance = fraction * totalDistance
        let eta = departure.addingTimeInterval(travelTime * fraction)

        if k == 0 {
            samples.append(CommuteSample(coordinate: route[0], eta: eta, fraction: fraction))
            continue
        }

        if k == count - 1 {
            samples.append(CommuteSample(coordinate: route[route.count - 1], eta: eta, fraction: fraction))
            continue
        }

        while currentSegmentIndex < segmentDistances.count - 1 &&
              cumulativeDistances[currentSegmentIndex + 1] < targetDistance {
            currentSegmentIndex += 1
        }

        let segLen = segmentDistances[currentSegmentIndex]
        let startDist = cumulativeDistances[currentSegmentIndex]
        let p0 = route[currentSegmentIndex]
        let p1 = route[currentSegmentIndex + 1]

        let coord: CLLocationCoordinate2D
        if segLen <= 0.0 {
            coord = p0
        } else {
            let t = max(0.0, min(1.0, (targetDistance - startDist) / segLen))
            let lat = p0.latitude + t * (p1.latitude - p0.latitude)
            let lon = p0.longitude + t * (p1.longitude - p0.longitude)
            coord = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }

        samples.append(CommuteSample(coordinate: coord, eta: eta, fraction: fraction))
    }

    return samples
}

/// Samples a polyline evenly by distance (not by vertex index) with:
/// `ETA = departure + travelTime * fraction`.
/// Handles routes of 1 point and repeated points without dividing by zero.
public func samplePoints(
    route: [CLLocationCoordinate2D],
    travelTime: TimeInterval,
    departure: Date,
    count: Int = 4
) -> [RoutePoint] {
    sampleRoute(route: route, travelTime: travelTime, departure: departure, count: count).map(\.point)
}

/// Commute planner service orchestrating route acquisition and point sampling.
public struct CommutePlanner: Sendable {
    public let routeProvider: any RouteProviding

    public init(routeProvider: any RouteProviding) {
        self.routeProvider = routeProvider
    }

    public func sample(
        from origin: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D,
        departure: Date = Date(),
        count: Int = 4
    ) async throws -> [CommuteSample] {
        let route = try await routeProvider.calculateRoute(from: origin, to: destination)
        return Upthere.sampleRoute(
            route: route.coordinates,
            travelTime: route.expectedTravelTime,
            departure: departure,
            count: count
        )
    }

    public func plan(
        from origin: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D,
        departure: Date = Date(),
        count: Int = 4
    ) async throws -> [RoutePoint] {
        let samples = try await sample(from: origin, to: destination, departure: departure, count: count)
        return samples.map(\.point)
    }

    public static func samplePoints(
        route: [CLLocationCoordinate2D],
        travelTime: TimeInterval,
        departure: Date,
        count: Int = 4
    ) -> [RoutePoint] {
        Upthere.samplePoints(route: route, travelTime: travelTime, departure: departure, count: count)
    }

    public static func sampleRoute(
        route: [CLLocationCoordinate2D],
        travelTime: TimeInterval,
        departure: Date,
        count: Int = 4
    ) -> [CommuteSample] {
        Upthere.sampleRoute(route: route, travelTime: travelTime, departure: departure, count: count)
    }
}
