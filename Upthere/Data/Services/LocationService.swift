import Foundation
import CoreLocation
import Observation

public enum LocationResolutionStatus: Equatable, Sendable {
    case liveGPS(CLLocation)
    case approximateGPS(CLLocation)
    case manualSelected(SavedLocation)
    case fallbackDefault(reason: String)
}

public enum LocationServiceError: LocalizedError, Sendable {
    case servicesDisabled
    case permissionDenied
    case restricted
    case timeout
    case invalidCoordinates

    public var errorDescription: String? {
        switch self {
        case .servicesDisabled:
            return "Location Services are disabled on this device."
        case .permissionDenied:
            return "Location permission was denied. You can enable it in iOS Settings."
        case .restricted:
            return "Location access is restricted on this device."
        case .timeout:
            return "Location request timed out. Using fallback location."
        case .invalidCoordinates:
            return "Received invalid GPS coordinates."
        }
    }
}

@Observable
@MainActor
public final class LocationService: NSObject, CLLocationManagerDelegate {
    public static let shared = LocationService()

    // Explicit Default Fallback Location: Ghaziabad, Uttar Pradesh, India
    public static let fallbackCoordinate = CLLocation(latitude: 28.6692, longitude: 77.4538)
    public static let fallbackCityName = "Ghaziabad"
    public static let fallbackRegionName = "Uttar Pradesh, India"

    public private(set) var authorizationStatus: CLAuthorizationStatus
    public private(set) var accuracyAuthorization: CLAccuracyAuthorization
    public private(set) var isLocationServicesEnabled: Bool
    public private(set) var currentLocation: CLLocation?
    public private(set) var currentCityName: String = fallbackCityName
    public private(set) var currentSubtitle: String = ""

    public var onLocationChanged: ((CLLocation) -> Void)?

    private let clManager: CLLocationManager
    private let geocoder = CLGeocoder()
    private var locationContinuations: [CheckedContinuation<CLLocation, Error>] = []
    private var lastRequestTime: Date?

    public override init() {
        let manager = CLLocationManager()
        self.clManager = manager
        self.authorizationStatus = manager.authorizationStatus
        self.accuracyAuthorization = manager.accuracyAuthorization
        self.isLocationServicesEnabled = CLLocationManager.locationServicesEnabled()
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
        manager.distanceFilter = 1000 // 1 kilometer to prevent battery drain
    }

    public func requestAuthorization() {
        guard isLocationServicesEnabled else { return }
        if authorizationStatus == .notDetermined {
            clManager.requestWhenInUseAuthorization()
        }
    }

    public var isAuthorized: Bool {
        #if os(iOS)
        return authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
        #else
        return authorizationStatus == .authorizedAlways
        #endif
    }

    public var isReducedAccuracy: Bool {
        accuracyAuthorization == .reducedAccuracy
    }

    public func requestCurrentLocation(force: Bool = false) async throws -> CLLocation {
        self.isLocationServicesEnabled = CLLocationManager.locationServicesEnabled()
        guard isLocationServicesEnabled else {
            throw LocationServiceError.servicesDisabled
        }

        if authorizationStatus == .denied {
            throw LocationServiceError.permissionDenied
        }
        if authorizationStatus == .restricted {
            throw LocationServiceError.restricted
        }

        // Return recent valid cached location if fresh (< 30 seconds) and not forced
        if !force, let location = currentLocation,
           Date().timeIntervalSince(location.timestamp) < 30,
           isValidCoordinate(location.coordinate) {
            return location
        }

        if authorizationStatus == .notDetermined {
            requestAuthorization()
        }

        // Use a 3.5-second timeout to prevent infinite hangs indoors / no-GPS
        return try await withThrowingTaskGroup(of: CLLocation.self) { group in
            group.addTask { @MainActor [weak self] in
                guard let self = self else { throw LocationServiceError.timeout }
                return try await withCheckedThrowingContinuation { continuation in
                    Task { @MainActor in
                        self.locationContinuations.append(continuation)
                        self.clManager.requestLocation()
                    }
                }
            }

            group.addTask {
                try await Task.sleep(nanoseconds: 3_500_000_000)
                throw LocationServiceError.timeout
            }

            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }

    public func isValidCoordinate(_ coord: CLLocationCoordinate2D) -> Bool {
        guard coord.latitude.isFinite, coord.longitude.isFinite else { return false }
        guard coord.latitude >= -90.0, coord.latitude <= 90.0 else { return false }
        guard coord.longitude >= -180.0, coord.longitude <= 180.0 else { return false }
        return true
    }

    public func reverseGeocode(location: CLLocation) async -> (cityName: String, subtitle: String) {
        guard isValidCoordinate(location.coordinate) else {
            return (Self.fallbackCityName, "Default location · \(Self.fallbackRegionName)")
        }

        // Fast-path: recognize common preset coordinates immediately
        if let presetCity = matchPresetCity(for: location.coordinate) {
            let sub = formatSubtitle(forPreset: presetCity)
            self.currentCityName = presetCity
            self.currentSubtitle = sub
            return (presetCity, sub)
        }

        // Reverse geocode with 2.5-second timeout
        let geocodedCity: String? = await withTaskGroup(of: String?.self) { group in
            group.addTask { [geocoder] in
                do {
                    let placemarks = try await geocoder.reverseGeocodeLocation(location)
                    if let placemark = placemarks.first {
                        return placemark.locality ?? placemark.subAdministrativeArea ?? placemark.name
                    }
                } catch {
                    // Apple's server failed or timed out
                }
                return nil
            }
            group.addTask {
                try? await Task.sleep(nanoseconds: 2_500_000_000)
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }

        let resolvedCity: String
        let subtitle: String

        if let geocodedCity = geocodedCity, !geocodedCity.isEmpty {
            resolvedCity = geocodedCity
            subtitle = isReducedAccuracy ? "Approximate location" : formatCurrentDateSubtitle()
        } else if location.distance(from: Self.fallbackCoordinate) < 25_000 {
            resolvedCity = Self.fallbackCityName
            subtitle = "Default location · \(Self.fallbackRegionName)"
        } else {
            let latStr = String(format: "%.2f", location.coordinate.latitude)
            let lonStr = String(format: "%.2f", location.coordinate.longitude)
            resolvedCity = "Location (\(latStr), \(lonStr))"
            subtitle = isReducedAccuracy ? "Approximate location" : formatCurrentDateSubtitle()
        }

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
            if abs(coord.latitude - p.lat) < 0.25 && abs(coord.longitude - p.lon) < 0.25 {
                return p.name
            }
        }
        return nil
    }

    private func formatSubtitle(forPreset city: String) -> String {
        let prefix = isReducedAccuracy ? "Approximate location" : "Current location"
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "EEE d MMM, h:mm a"
        return "\(prefix) · \(formatter.string(from: Date()))"
    }

    private func formatCurrentDateSubtitle() -> String {
        let prefix = isReducedAccuracy ? "Approximate location" : "Current location"
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "EEE d MMM, h:mm a"
        return "\(prefix) · \(formatter.string(from: Date()))"
    }

    // MARK: - Lifecycle

    public func pauseLocationUpdates() {
        clManager.stopUpdatingLocation()
    }

    public func resumeLocationUpdates() {
        if isAuthorized {
            clManager.startUpdatingLocation()
        }
    }

    // MARK: - CLLocationManagerDelegate

    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        self.authorizationStatus = manager.authorizationStatus
        self.accuracyAuthorization = manager.accuracyAuthorization
        self.isLocationServicesEnabled = CLLocationManager.locationServicesEnabled()
        if isAuthorized {
            manager.startUpdatingLocation()
            manager.requestLocation()
        }
    }

    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last, isValidCoordinate(location.coordinate) else { return }
        let previous = self.currentLocation
        self.currentLocation = location

        let continuations = self.locationContinuations
        self.locationContinuations.removeAll()
        for continuation in continuations {
            continuation.resume(returning: location)
        }

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
