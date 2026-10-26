import Testing
import Foundation
import CoreLocation
@testable import Upthere

@Suite("LocationService Tests", .serialized)
struct LocationServiceTests {

    @Test("A location request that never answers throws .timeout within about 4 seconds")
    @MainActor
    func testRequestLocationNeverAnswersThrowsTimeout() async throws {
        let sleeper = ManualSleeper()
        let fakeManager = FakeLocationManager()
        let service = LocationService(
            manager: fakeManager,
            isLocationServicesEnabledProvider: { true },
            timeoutSleep: { try await sleeper.sleep($0) },
            geocodeTimeout: .zero
        )

        let task = Task { @MainActor in
            try await service.requestCurrentLocation(force: true)
        }

        await sleeper.fire(afterRequests: 1)
        await Task.yield()

        do {
            _ = try await task.value
            Issue.record("Expected requestCurrentLocation to throw .timeout, but it succeeded.")
        } catch let error as LocationServiceError {
            #expect(error == .timeout)
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
            isLocationServicesEnabledProvider: { true },
            timeoutSleep: { _ in },
            geocodeTimeout: .zero
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
            isLocationServicesEnabledProvider: { true },
            timeoutSleep: { _ in },
            geocodeTimeout: .zero
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
        let sleeper = ManualSleeper()
        let service = LocationService(
            manager: fakeManager,
            isLocationServicesEnabledProvider: { true },
            timeoutSleep: { try await sleeper.sleep($0) },
            geocodeTimeout: .zero
        )

        fakeManager.onRequestLocation = { [weak service] in
            let dummy = CLLocationManager()
            let invalidLoc = CLLocation(latitude: 999.0, longitude: 999.0)
            service?.locationManager(dummy, didUpdateLocations: [invalidLoc])
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
        let sleeper = ManualSleeper()
        let fakeManager = FakeLocationManager()
        let service = LocationService(
            manager: fakeManager,
            isLocationServicesEnabledProvider: { true },
            timeoutSleep: { try await sleeper.sleep($0) },
            geocodeTimeout: .zero
        )

        // Start first request in background (generation 1)
        let task1 = Task { @MainActor in
            try await service.requestCurrentLocation(force: true)
        }

        // Start second request (generation 2)
        let task2 = Task { @MainActor in
            try await service.requestCurrentLocation(force: true)
        }

        // Fire timeout for generation 1 and assert request 2 is NOT failed
        await sleeper.fire(afterRequests: 2, index: 0)
        await Task.yield()

        // Deliver valid location now and assert request 2 succeeds
        let dummy = CLLocationManager()
        let validLoc = CLLocation(latitude: 28.6692, longitude: 77.4538)
        service.locationManager(dummy, didUpdateLocations: [validLoc])

        let loc2 = try await task2.value
        #expect(loc2.coordinate.latitude == 28.6692)
        _ = try? await task1.value

        // Then fire timeout for generation 2 on a fresh request and assert it throws .timeout
        let freshSleeper = ManualSleeper()
        let freshFakeManager = FakeLocationManager()
        let freshService = LocationService(
            manager: freshFakeManager,
            isLocationServicesEnabledProvider: { true },
            timeoutSleep: { try await freshSleeper.sleep($0) },
            geocodeTimeout: .zero
        )

        let freshTask1 = Task { @MainActor in
            try await freshService.requestCurrentLocation(force: true)
        }
        let freshTask2 = Task { @MainActor in
            try await freshService.requestCurrentLocation(force: true)
        }

        await freshSleeper.fire(afterRequests: 2)
        await Task.yield()

        do {
            _ = try await freshTask2.value
            Issue.record("Expected request 2 to throw .timeout, but it succeeded.")
        } catch let error as LocationServiceError {
            #expect(error == .timeout)
        } catch {
            Issue.record("Unexpected error thrown: \(error)")
        }
        _ = try? await freshTask1.value
    }
}
