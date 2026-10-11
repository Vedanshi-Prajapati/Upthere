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

    public var onLocationChanged: ((CLLocation) -> Void)?

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
        if isAuthorized {
            manager.startUpdatingLocation()
        }
    }

    public func requestAuthorization() {
        clManager.requestWhenInUseAuthorization()
    }

    public var isAuthorized: Bool {
        authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
    }

    public func requestCurrentLocation(force: Bool = false) async throws -> CLLocation {
        if !force, let location = currentLocation, Date().timeIntervalSince(location.timestamp) < 15 {
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
        // Fast-path: check known preset coordinates (for simulator and major cities)
        let presetCity = matchPresetCity(for: location.coordinate)

        // Try Apple's CLGeocoder with a 2.5-second timeout to prevent network hangs on Simulator
        let geocodedCity: String? = await withTaskGroup(of: String?.self) { group in
            group.addTask { [geocoder] in
                do {
                    let placemarks = try await geocoder.reverseGeocodeLocation(location)
                    if let placemark = placemarks.first {
                        return placemark.locality ?? placemark.subAdministrativeArea ?? placemark.name
                    }
                } catch {
                    // Apple's server timed out or failed
                }
                return nil
            }
            group.addTask {
                try? await Task.sleep(nanoseconds: 2_500_000_000)
                return nil
            }
            let firstResult = await group.next() ?? nil
            group.cancelAll()
            return firstResult
        }

        let resolvedCity: String
        if let geocodedCity = geocodedCity, !geocodedCity.isEmpty {
            resolvedCity = geocodedCity
        } else if let presetCity = presetCity {
            resolvedCity = presetCity
        } else if location.distance(from: Self.defaultCoordinate) < 30_000 {
            resolvedCity = Self.defaultCityName
        } else {
            // Coordinate fallback when geocoding service times out
            let latStr = String(format: "%.2f", location.coordinate.latitude)
            let lonStr = String(format: "%.2f", location.coordinate.longitude)
            resolvedCity = "Location (\(latStr), \(lonStr))"
        }

        let subtitle = formatCurrentDateSubtitle()
        self.currentCityName = resolvedCity
        self.currentSubtitle = subtitle
        return (resolvedCity, subtitle)
    }

    private func matchPresetCity(for coord: CLLocationCoordinate2D) -> String? {
        let presets: [(name: String, lat: Double, lon: Double)] = [
            ("Sydney", -33.8688, 151.2093),
            ("Cupertino", 37.3230, -122.0322),
            ("San Francisco", 37.7749, -122.4194),
            ("New York", 40.7128, -74.0060),
            ("London", 51.5074, -0.1278),
            ("Tokyo", 35.6762, 139.6503),
            ("Paris", 48.8566, 2.3522),
            ("Berlin", 52.5200, 13.4050),
            ("Dubai", 25.2048, 55.2708),
            ("Singapore", 1.3521, 103.8198),
            ("Delhi", 28.6139, 77.2090),
            ("Ghaziabad", 28.6692, 77.4538),
            ("Mumbai", 19.0760, 72.8777),
            ("Bengaluru", 12.9716, 77.5946),
            ("Pune", 18.5204, 73.8567),
            ("Jaipur", 26.9124, 75.7873),
            ("Chennai", 13.0827, 80.2707),
            ("Kolkata", 22.5726, 88.3639)
        ]

        for p in presets {
            let latDiff = abs(coord.latitude - p.lat)
            let lonDiff = abs(coord.longitude - p.lon)
            if latDiff < 0.25 && lonDiff < 0.25 {
                return p.name
            }
        }
        return nil
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
            clManager.startUpdatingLocation()
            clManager.requestLocation()
        }
    }

    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        let previous = self.currentLocation
        self.currentLocation = location

        let continuations = self.locationContinuations
        self.locationContinuations.removeAll()
        for continuation in continuations {
            continuation.resume(returning: location)
        }

        // Notify if location changed significantly (> 500m)
        if let previous = previous {
            if location.distance(from: previous) > 500 {
                onLocationChanged?(location)
            }
        } else {
            onLocationChanged?(location)
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
