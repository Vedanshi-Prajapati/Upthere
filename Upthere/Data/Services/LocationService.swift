import Foundation
import CoreLocation
import MapKit
import Observation

enum LocationResolutionStatus: Equatable, Sendable {
    case liveGPS(CLLocation)
    case approximateGPS(CLLocation)
    case manualSelected(SavedLocation)
    case fallbackDefault(reason: String)
}

enum LocationServiceError: LocalizedError, Sendable {
    case servicesDisabled
    case permissionDenied
    case restricted
    case timeout
    case invalidCoordinates

    var errorDescription: String? {
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

protocol LocationManagerProtocol: AnyObject {
    var delegate: CLLocationManagerDelegate? { get set }
    var desiredAccuracy: CLLocationAccuracy { get set }
    var distanceFilter: CLLocationDistance { get set }
    var authorizationStatus: CLAuthorizationStatus { get }
    var accuracyAuthorization: CLAccuracyAuthorization { get }
    func requestWhenInUseAuthorization()
    func requestLocation()
    func startUpdatingLocation()
    func stopUpdatingLocation()
}

extension CLLocationManager: LocationManagerProtocol {}

@Observable
@MainActor
final class LocationService: NSObject, CLLocationManagerDelegate {
    static let shared = LocationService()

    // Explicit Default Fallback Location: Ghaziabad, Uttar Pradesh, India
    static let fallbackCoordinate = CLLocation(latitude: 28.6692, longitude: 77.4538)
    static let fallbackCityName = "Ghaziabad"
    static let fallbackRegionName = "Uttar Pradesh, India"

    private(set) var authorizationStatus: CLAuthorizationStatus
    private(set) var accuracyAuthorization: CLAccuracyAuthorization
    private(set) var isLocationServicesEnabled: Bool
    private(set) var currentLocation: CLLocation?
    private(set) var currentCityName: String = fallbackCityName
    private(set) var currentSubtitle: String = ""

    private var streamContinuations: [UUID: AsyncStream<CLLocation>.Continuation] = [:]

    var locationUpdates: AsyncStream<CLLocation> {
        AsyncStream { continuation in
            let id = UUID()
            self.streamContinuations[id] = continuation
            continuation.onTermination = { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.streamContinuations.removeValue(forKey: id)
                }
            }
        }
    }

    private let clManager: any LocationManagerProtocol
    private let isLocationServicesEnabledProvider: (@Sendable () -> Bool)?
    private let timeoutSleep: @Sendable (Duration) async throws -> Void
    private let requestTimeout: Duration
    private let geocodeTimeout: Duration
    private var locationContinuations: [CheckedContinuation<CLLocation, Error>] = []
    private var authContinuations: [CheckedContinuation<CLAuthorizationStatus, Never>] = []
    private var requestGeneration: Int = 0
    private var geocodeCache: [String: (cityName: String, subtitle: String)] = [:]

    convenience override init() {
        self.init(manager: CLLocationManager(), isLocationServicesEnabledProvider: nil)
    }

    init(
        manager: any LocationManagerProtocol,
        isLocationServicesEnabledProvider: (@Sendable () -> Bool)? = nil,
        timeoutSleep: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) },
        requestTimeout: Duration = .seconds(3.5),
        geocodeTimeout: Duration = .seconds(2.5)
    ) {
        self.clManager = manager
        self.isLocationServicesEnabledProvider = isLocationServicesEnabledProvider
        self.timeoutSleep = timeoutSleep
        self.requestTimeout = requestTimeout
        self.geocodeTimeout = geocodeTimeout
        self.authorizationStatus = manager.authorizationStatus
        self.accuracyAuthorization = manager.accuracyAuthorization
        self.isLocationServicesEnabled = true
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
        manager.distanceFilter = 1000 // 1 kilometer to prevent battery drain
    }

    func requestAuthorization() {
        if authorizationStatus == .notDetermined {
            clManager.requestWhenInUseAuthorization()
        }
    }

    var isAuthorized: Bool {
        #if os(iOS)
        return authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
        #else
        return authorizationStatus == .authorizedAlways
        #endif
    }

    var isReducedAccuracy: Bool {
        accuracyAuthorization == .reducedAccuracy
    }

    func requestCurrentLocation(force: Bool = false) async throws -> CLLocation {
        let servicesEnabled = await Task.detached(priority: .userInitiated) { [isLocationServicesEnabledProvider] in
            if let custom = isLocationServicesEnabledProvider {
                return custom()
            }
            return CLLocationManager.locationServicesEnabled()
        }.value
        self.isLocationServicesEnabled = servicesEnabled
        guard servicesEnabled else {
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

        // If authorization is not determined yet, wait for user response via locationManagerDidChangeAuthorization
        if authorizationStatus == .notDetermined {
            requestAuthorization()
            let newStatus = await withCheckedContinuation { continuation in
                self.authContinuations.append(continuation)
            }
            #if os(iOS)
            guard newStatus == .authorizedWhenInUse || newStatus == .authorizedAlways else {
                throw LocationServiceError.permissionDenied
            }
            #else
            guard newStatus == .authorizedAlways else {
                throw LocationServiceError.permissionDenied
            }
            #endif
        }

        guard isAuthorized else {
            throw LocationServiceError.permissionDenied
        }

        requestGeneration += 1
        let generation = requestGeneration

        // Request timeout task tied to this request generation
        Task { [weak self, timeoutSleep, requestTimeout] in
            try? await timeoutSleep(requestTimeout)
            guard let self = self else { return }
            self.handleTimeout(for: generation)
        }

        let location = try await withCheckedThrowingContinuation { continuation in
            self.locationContinuations.append(continuation)
            self.clManager.requestLocation()
        }

        // Current-location flow: update currentCityName and currentSubtitle
        let geo = await reverseGeocode(location: location)
        self.currentCityName = geo.cityName
        self.currentSubtitle = geo.subtitle

        return location
    }

    private func handleTimeout(for generation: Int) {
        guard self.requestGeneration == generation else {
            // Newer request already in flight or already resolved
            return
        }
        resumeContinuations(with: .failure(LocationServiceError.timeout))
    }

    private func resumeContinuations(with result: Result<CLLocation, Error>) {
        guard !locationContinuations.isEmpty else { return }
        let continuations = self.locationContinuations
        self.locationContinuations.removeAll()
        self.requestGeneration += 1
        for continuation in continuations {
            continuation.resume(with: result)
        }
    }

    func isValidCoordinate(_ coord: CLLocationCoordinate2D) -> Bool {
        guard coord.latitude.isFinite, coord.longitude.isFinite else { return false }
        guard coord.latitude >= -90.0, coord.latitude <= 90.0 else { return false }
        guard coord.longitude >= -180.0, coord.longitude <= 180.0 else { return false }
        return true
    }

    /// Pure reverse geocode: returns (cityName, subtitle) without mutating currentCityName or currentSubtitle.
    func reverseGeocode(location: CLLocation) async -> (cityName: String, subtitle: String) {
        guard isValidCoordinate(location.coordinate) else {
            return (Self.fallbackCityName, "Default location · \(Self.fallbackRegionName)")
        }

        let latRounded = String(format: "%.2f", location.coordinate.latitude)
        let lonRounded = String(format: "%.2f", location.coordinate.longitude)
        let cacheKey = "\(latRounded),\(lonRounded)"

        if let cached = geocodeCache[cacheKey] {
            return (cached.cityName, isReducedAccuracy ? "Approximate location" : formatCurrentDateSubtitle())
        }

        // Reverse geocode with timeout
        let geocodedCity: String?
        if geocodeTimeout <= .zero {
            geocodedCity = nil
        } else {
            geocodedCity = await withTaskGroup(of: String?.self) { group in
                group.addTask {
                    do {
                        guard let request = MKReverseGeocodingRequest(location: location) else { return nil }
                        let mapItems = try await request.mapItems
                        if let first = mapItems.first {
                            return first.addressRepresentations?.cityName ?? first.name
                        }
                    } catch {
                        // Apple's reverse geocoding failed or timed out
                    }
                    return nil
                }
                group.addTask { [timeoutSleep, geocodeTimeout] in
                    try? await timeoutSleep(geocodeTimeout)
                    return nil
                }
                let first = await group.next() ?? nil
                group.cancelAll()
                return first
            }
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

        geocodeCache[cacheKey] = (resolvedCity, subtitle)
        return (resolvedCity, subtitle)
    }

    private func formatCurrentDateSubtitle() -> String {
        let prefix = isReducedAccuracy ? "Approximate location" : "Current location"
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "EEE d MMM, h:mm a"
        return "\(prefix) · \(formatter.string(from: Date()))"
    }

    // MARK: - Lifecycle

    func pauseLocationUpdates() {
        clManager.stopUpdatingLocation()
    }

    func resumeLocationUpdates() {
        if isAuthorized {
            clManager.startUpdatingLocation()
        }
    }

    // MARK: - CLLocationManagerDelegate

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        self.authorizationStatus = manager.authorizationStatus
        self.accuracyAuthorization = manager.accuracyAuthorization

        let callbacks = self.authContinuations
        self.authContinuations.removeAll()
        for cont in callbacks {
            cont.resume(returning: manager.authorizationStatus)
        }

        if isAuthorized {
            clManager.requestLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        guard isValidCoordinate(location.coordinate) else {
            resumeContinuations(with: .failure(LocationServiceError.invalidCoordinates))
            return
        }

        let previous = self.currentLocation
        self.currentLocation = location

        resumeContinuations(with: .success(location))

        Task { @MainActor [weak self] in
            guard let self = self else { return }
            let geo = await self.reverseGeocode(location: location)
            self.currentCityName = geo.cityName
            self.currentSubtitle = geo.subtitle
        }

        let shouldNotify: Bool
        if let previous = previous {
            shouldNotify = location.distance(from: previous) > 500
        } else {
            shouldNotify = true
        }

        if shouldNotify {
            for continuation in streamContinuations.values {
                continuation.yield(location)
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        resumeContinuations(with: .failure(error))
    }
}
