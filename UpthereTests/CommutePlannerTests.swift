import Testing
import Foundation
import CoreLocation
@testable import Upthere

@Suite("CommutePlanner Tests")
struct CommutePlannerTests {

    let departure = Date(timeIntervalSince1970: 1_700_000_000)
    let travelTime: TimeInterval = 1800 // 30 minutes

    @Test("Straight route samples at 0, 1/3, 2/3, 1 of the distance")
    func straightRouteSamplesAtFractions() {
        let origin = CLLocationCoordinate2D(latitude: 37.0, longitude: -122.0)
        let destination = CLLocationCoordinate2D(latitude: 37.3, longitude: -122.0)
        let route = [origin, destination]

        let points = samplePoints(
            route: route,
            travelTime: travelTime,
            departure: departure,
            count: 4
        )

        #expect(points.count == 4)

        // Coordinates should be at 0, 1/3, 2/3, 1 along latitude
        #expect(abs(points[0].coordinate.latitude - 37.0) < 0.0001)
        #expect(abs(points[0].coordinate.longitude - (-122.0)) < 0.0001)

        #expect(abs(points[1].coordinate.latitude - 37.1) < 0.0001)
        #expect(abs(points[1].coordinate.longitude - (-122.0)) < 0.0001)

        #expect(abs(points[2].coordinate.latitude - 37.2) < 0.0001)
        #expect(abs(points[2].coordinate.longitude - (-122.0)) < 0.0001)

        #expect(abs(points[3].coordinate.latitude - 37.3) < 0.0001)
        #expect(abs(points[3].coordinate.longitude - (-122.0)) < 0.0001)

        // ETAs should be at 0, 1/3, 2/3, 1 of travel time (600s intervals)
        #expect(points[0].eta == departure)
        #expect(points[1].eta == departure.addingTimeInterval(600))
        #expect(points[2].eta == departure.addingTimeInterval(1200))
        #expect(points[3].eta == departure.addingTimeInterval(1800))

        // Also test sampleRoute to verify exact progress fractions
        let samples = sampleRoute(
            route: route,
            travelTime: travelTime,
            departure: departure,
            count: 4
        )
        #expect(samples.count == 4)
        #expect(abs(samples[0].fraction - 0.0) < 0.0001)
        #expect(abs(samples[1].fraction - 1.0 / 3.0) < 0.0001)
        #expect(abs(samples[2].fraction - 2.0 / 3.0) < 0.0001)
        #expect(abs(samples[3].fraction - 1.0) < 0.0001)
    }

    @Test("A single-point route returns that point 4 times with the departure time")
    func singlePointRouteReturnsFourPointsWithDepartureTime() {
        let single = CLLocationCoordinate2D(latitude: 28.6692, longitude: 77.4538)
        let route = [single]

        let points = samplePoints(
            route: route,
            travelTime: travelTime,
            departure: departure,
            count: 4
        )

        #expect(points.count == 4)
        for point in points {
            #expect(point.coordinate.latitude == single.latitude)
            #expect(point.coordinate.longitude == single.longitude)
            #expect(point.eta == departure)
        }
    }

    @Test("Zero-length route does not crash")
    func zeroLengthRouteDoesNotCrash() {
        // 1. Completely empty coordinates array
        let emptyPoints = samplePoints(
            route: [],
            travelTime: travelTime,
            departure: departure,
            count: 4
        )
        #expect(emptyPoints.isEmpty)

        // 2. Repeated identical points where total distance == 0
        let single = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        let repeatedPoints = [single, single, single]
        let points = samplePoints(
            route: repeatedPoints,
            travelTime: travelTime,
            departure: departure,
            count: 4
        )
        #expect(points.count == 4)
        for point in points {
            #expect(point.coordinate.latitude == single.latitude)
            #expect(point.coordinate.longitude == single.longitude)
            #expect(point.eta == departure)
        }

        // 3. Count is 0 or negative
        #expect(samplePoints(route: [single], travelTime: travelTime, departure: departure, count: 0).isEmpty)
        #expect(samplePoints(route: [single], travelTime: travelTime, departure: departure, count: -2).isEmpty)
    }

    @Test("ETA is monotonically increasing")
    func etaIsMonotonicallyIncreasing() {
        // Multi-segment polyline route with varying segment lengths
        let c0 = CLLocationCoordinate2D(latitude: 37.0, longitude: -122.0)
        let c1 = CLLocationCoordinate2D(latitude: 37.1, longitude: -122.0)
        let c2 = CLLocationCoordinate2D(latitude: 37.1, longitude: -121.8)
        let c3 = CLLocationCoordinate2D(latitude: 37.4, longitude: -121.8)
        let route = [c0, c1, c2, c3]

        let points = samplePoints(
            route: route,
            travelTime: 3600,
            departure: departure,
            count: 8
        )

        #expect(points.count == 8)
        for i in 1..<points.count {
            #expect(points[i].eta >= points[i - 1].eta)
            #expect(points[i].eta > points[i - 1].eta)
        }
    }

    @Test("Multi-segment route samples evenly by distance, not by vertex index")
    func multiSegmentSamplesByDistanceNotByVertexIndex() {
        // Segment 1 length: 1 unit (lat 37.0 -> 37.1)
        // Segment 2 length: 2 units (lat 37.1 -> 37.3)
        // Total distance: 3 units
        // 4 samples should land at 0, 1/3, 2/3, 1 of 3 units => distances 0, 1, 2, 3
        // So coordinates should be: 37.0, 37.1, 37.2, 37.3
        let p0 = CLLocationCoordinate2D(latitude: 37.0, longitude: -122.0)
        let p1 = CLLocationCoordinate2D(latitude: 37.1, longitude: -122.0)
        let p2 = CLLocationCoordinate2D(latitude: 37.3, longitude: -122.0)
        let route = [p0, p1, p2]

        let points = samplePoints(
            route: route,
            travelTime: travelTime,
            departure: departure,
            count: 4
        )

        #expect(points.count == 4)
        #expect(abs(points[0].coordinate.latitude - 37.0) < 0.001)
        #expect(abs(points[1].coordinate.latitude - 37.1) < 0.001)
        #expect(abs(points[2].coordinate.latitude - 37.2) < 0.001)
        #expect(abs(points[3].coordinate.latitude - 37.3) < 0.001)
    }

    @Test("CommutePlanner integrates with RouteProviding fake without network")
    func commutePlannerWithFakeRouteProvider() async throws {
        let origin = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        let destination = CLLocationCoordinate2D(latitude: 37.3382, longitude: -121.8863)

        let fakeRoute = CommuteRoute(
            coordinates: [origin, destination],
            expectedTravelTime: 2400,
            distance: 75000,
            name: "Highway 101 S"
        )
        let fakeProvider = FakeRouteProvider(routeToReturn: fakeRoute)
        let planner = CommutePlanner(routeProvider: fakeProvider)

        let points = try await planner.plan(
            from: origin,
            to: destination,
            departure: departure,
            count: 4
        )

        #expect(fakeProvider.callCount == 1)
        #expect(fakeProvider.lastOrigin?.latitude == origin.latitude)
        #expect(fakeProvider.lastDestination?.latitude == destination.latitude)
        #expect(points.count == 4)
        #expect(points.first?.eta == departure)
        #expect(points.last?.eta == departure.addingTimeInterval(2400))
    }
}
