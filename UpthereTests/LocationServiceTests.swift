import Testing
import Foundation
import CoreLocation
@testable import Upthere

@MainActor
final class FakeLocationManager: LocationManagerProtocol {
    weak var delegate: CLLocationManagerDelegate?
    var desiredAccuracy: CLLocationAccuracy = kCLLocationAccuracyKilometer
    var distanceFilter: CLLocationDistance = 1000
    var authorizationStatus: CLAuthorizationStatus = .authorizedWhenInUse
    var accuracyAuthorization: CLAccuracyAuthorization = .fullAccuracy

    var requestLocationCallCount = 0
    var startUpdatingLocationCallCount = 0
    var stopUpdatingLocationCallCount = 0
    var requestWhenInUseAuthorizationCallCount = 0

    func requestWhenInUseAuthorization() {
        requestWhenInUseAuthorizationCallCount += 1
    }

    func requestLocation() {
        requestLocationCallCount += 1
        // Intentionally do not respond to simulate a request that never answers
    }

    func startUpdatingLocation() {
        startUpdatingLocationCallCount += 1
    }

    func stopUpdatingLocation() {
        stopUpdatingLocationCallCount += 1
    }
}

@Suite("LocationService Tests")
struct LocationServiceTests {

    @Test("A location request that never answers throws .timeout within about 4 s")
    @MainActor
    func testRequestLocationNeverAnswersThrowsTimeout() async throws {
        let fakeManager = FakeLocationManager()
        let service = LocationService(
            manager: fakeManager,
            isLocationServicesEnabledProvider: { true }
        )

        let startTime = Date()
        do {
            _ = try await service.requestCurrentLocation(force: true)
            Issue.record("Expected requestCurrentLocation to throw .timeout, but it succeeded.")
        } catch let error as LocationServiceError {
            let elapsed = Date().timeIntervalSince(startTime)
            #expect(error == .timeout)
            // Should timeout around 3.5s (within about 4s)
            #expect(elapsed >= 3.3 && elapsed <= 4.5, "Elapsed time was \(elapsed)s")
        } catch {
            Issue.record("Unexpected error thrown: \(error)")
        }
    }

    @Test("The Ghaziabad coordinate no longer returns Delhi")
    @MainActor
    func testGhaziabadCoordinateDoesNotReturnDelhi() async {
        let fakeManager = FakeLocationManager()
        let service = LocationService(
            manager: fakeManager,
            isLocationServicesEnabledProvider: { true }
        )

        let ghaziabadCoord = CLLocation(latitude: 28.6692, longitude: 77.4538)
        let result = await service.reverseGeocode(location: ghaziabadCoord)

        #expect(result.cityName == "Ghaziabad")
        #expect(result.cityName != "Delhi")
    }

    @Test("Reverse geocoding a saved city leaves currentCityName unchanged")
    @MainActor
    func testReverseGeocodingSavedCityLeavesCurrentCityNameUnchanged() async {
        let fakeManager = FakeLocationManager()
        let service = LocationService(
            manager: fakeManager,
            isLocationServicesEnabledProvider: { true }
        )

        // Initial currentCityName
        let initialCity = service.currentCityName
        #expect(initialCity == "Ghaziabad")

        // Reverse geocoding another city
        let savedCityLocation = CLLocation(latitude: 37.3349, longitude: -122.0090)
        let result = await service.reverseGeocode(location: savedCityLocation)

        // Returned city should be for the queried coordinates, but service.currentCityName must NOT change
        #expect(result.cityName != "Ghaziabad")
        #expect(service.currentCityName == initialCity)
    }

    @Test("Invalid coordinate in didUpdateLocations resumes continuation with invalidCoordinates error")
    @MainActor
    func testInvalidCoordinateResumesWithError() async {
        let fakeManager = FakeLocationManager()
        let service = LocationService(
            manager: fakeManager,
            isLocationServicesEnabledProvider: { true }
        )

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 100_000_000)
            let dummy = CLLocationManager()
            let invalidLoc = CLLocation(latitude: 999.0, longitude: 999.0)
            service.locationManager(dummy, didUpdateLocations: [invalidLoc])
        }

        do {
            _ = try await service.requestCurrentLocation(force: true)
            Issue.record("Expected .invalidCoordinates error")
        } catch let error as LocationServiceError {
            #expect(error == .invalidCoordinates)
        } catch {
            Issue.record("Unexpected error thrown: \(error)")
        }
    }

    @Test("Request generation counter prevents old timeout from failing newer request")
    @MainActor
    func testGenerationCounterPreventsOldTimeoutFromFailingNewerRequest() async throws {
        let fakeManager = FakeLocationManager()
        let service = LocationService(
            manager: fakeManager,
            isLocationServicesEnabledProvider: { true }
        )

        // Start first request in background (generation 1)
        let task1 = Task { @MainActor in
            try await service.requestCurrentLocation(force: true)
        }

        // Wait 1.0s, then start second request (generation 2)
        try await Task.sleep(nanoseconds: 1_000_000_000)
        let task2 = Task { @MainActor in
            try await service.requestCurrentLocation(force: true)
        }

        // Wait 3.0s (total 4.0s from start): generation 1 timeout (at 3.5s) should NOT fail generation 2
        // Deliver valid location now
        try await Task.sleep(nanoseconds: 2_600_000_000)
        let dummy = CLLocationManager()
        let validLoc = CLLocation(latitude: 28.6692, longitude: 77.4538)
        service.locationManager(dummy, didUpdateLocations: [validLoc])

        let loc2 = try await task2.value
        #expect(loc2.coordinate.latitude == 28.6692)
    }
}
