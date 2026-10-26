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

    var onRequestLocation: (() -> Void)?

    func requestWhenInUseAuthorization() {
        requestWhenInUseAuthorizationCallCount += 1
    }

    func requestLocation() {
        requestLocationCallCount += 1
        onRequestLocation?()
    }

    func startUpdatingLocation() {
        startUpdatingLocationCallCount += 1
    }

    func stopUpdatingLocation() {
        stopUpdatingLocationCallCount += 1
    }
}
