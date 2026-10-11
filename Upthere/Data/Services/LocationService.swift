import Foundation
import CoreLocation
import Observation

public enum LocationError: LocalizedError {
    case permissionDenied
    case locationUnavailable
    case timeout

    public var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Location permission is required to fetch weather for your current location."
        case .locationUnavailable:
            return "Unable to determine your current location."
        case .timeout:
            return "Location request timed out."
        }
    }
}

@Observable
@MainActor
public final class LocationService: NSObject, CLLocationManagerDelegate {
    public static let shared = LocationService()

    // Default fallback coordinate (Ghaziabad: 28.6692° N, 77.4538° E)
    public static let defaultCoordinate = CLLocation(latitude: 28.6692, longitude: 77.4538)
    public static let defaultCityName = "Ghaziabad"

    public private(set) var authorizationStatus: CLAuthorizationStatus
    public private(set) var currentLocation: CLLocation?
    public private(set) var currentCityName: String = defaultCityName
    public private(set) var currentSubtitle: String = ""

    private let clManager: CLLocationManager
    private let geocoder = CLGeocoder()
    private var locationContinuations: [CheckedContinuation<CLLocation, Error>] = []

    public override init() {
        let manager = CLLocationManager()
        self.clManager = manager
        self.authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    public func requestAuthorization() {
        clManager.requestWhenInUseAuthorization()
    }

    public var isAuthorized: Bool {
        authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
    }

    public func requestCurrentLocation() async throws -> CLLocation {
        if let location = currentLocation, Date().timeIntervalSince(location.timestamp) < 300 {
            return location
        }

        if authorizationStatus == .denied || authorizationStatus == .restricted {
            throw LocationError.permissionDenied
        }

        if authorizationStatus == .notDetermined {
            requestAuthorization()
        }

        return try await withCheckedThrowingContinuation { continuation in
            locationContinuations.append(continuation)
            clManager.requestLocation()
        }
    }

    public func reverseGeocode(location: CLLocation) async -> (cityName: String, subtitle: String) {
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            if let placemark = placemarks.first {
                let city = placemark.locality ?? placemark.subAdministrativeArea ?? placemark.name ?? Self.defaultCityName
                let subtitle = formatSubtitle(placemark: placemark)
                self.currentCityName = city
                self.currentSubtitle = subtitle
                return (city, subtitle)
            }
        } catch {
            // Geocoding failure fallback
        }
        let fallbackSubtitle = formatCurrentDateSubtitle()
        return (currentCityName, fallbackSubtitle)
    }

    private func formatSubtitle(placemark: CLPlacemark) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "EEE d MMM, h:mm a"
        let dateString = formatter.string(from: Date())
        return "Current location · \(dateString)"
    }

    private func formatCurrentDateSubtitle() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "EEE d MMM, h:mm a"
        return "Current location · \(formatter.string(from: Date()))"
    }

    // MARK: - CLLocationManagerDelegate

    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        self.authorizationStatus = manager.authorizationStatus
        if isAuthorized {
            clManager.requestLocation()
        }
    }

    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        self.currentLocation = location
        let continuations = self.locationContinuations
        self.locationContinuations.removeAll()
        for continuation in continuations {
            continuation.resume(returning: location)
        }
    }

    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let continuations = self.locationContinuations
        self.locationContinuations.removeAll()
        for continuation in continuations {
            continuation.resume(throwing: error)
        }
    }
}
