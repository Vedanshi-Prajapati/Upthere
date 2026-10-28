import Foundation
import CoreLocation
@preconcurrency import MapKit
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

extension LocationStatus {
    static func from(_ error: LocationServiceError) -> LocationStatus {
        switch error {
        case .permissionDenied:
            return .denied
        case .restricted:
            return .restricted
        case .servicesDisabled:
            return .servicesDisabled
        case .timeout:
            return .timedOut
        case .invalidCoordinates:
            return .unavailable
        }
    }

    static func from(_ error: Error?) -> LocationStatus {
        guard let error = error else { return .live }
        if let locError = error as? LocationServiceError {
            return from(locError)
        }
        return .unavailable
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

protocol GeocoderProtocol: Sendable {
    func reverseGeocode(location: CLLocation) async throws -> String?
}

final class SystemGeocoder: GeocoderProtocol {
    func reverseGeocode(location: CLLocation) async throws -> String? {
        guard let request = MKReverseGeocodingRequest(location: location) else { return nil }
        let mapItems = try await request.mapItems
        // Convert MKReverseGeocodingRequest results to a plain Sendable struct inside callback before returning
        let firstItem: MapItemData? = mapItems.first.map { item in
            MapItemData(
                name: item.name,
                locality: item.addressRepresentations?.cityName ?? item.placemark.locality,
                region: item.addressRepresentations?.regionName ?? item.placemark.administrativeArea,
                coordinate: item.location.coordinate
            )
        }
        return firstItem?.locality ?? firstItem?.name
    }
}

@Observable
@MainActor
final class LocationService: NSObject, CLLocationManagerDelegate {
    static let shared = LocationService()

    // Explicit Default Fallback Location: Ghaziabad, Uttar Pradesh, India
    static let fallbackCoordinate = CLLocation(latitude: 28.6692, longitude: 77.4538)
    static let fallbackCityName = "Ghaziabad"
    static let fallbackRegionName = "Uttar Pradesh, India"

    static let presetCities: [(name: String, lat: Double, lon: Double)] = [
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

    private(set) var authorizationStatus: CLAuthorizationStatus
    private(set) var accuracyAuthorization: CLAccuracyAuthorization
    private(set) var isLocationServicesEnabled: Bool
    private(set) var currentLocation: CLLocation?
    private(set) var currentCityName: String = fallbackCityName
    private(set) var currentSubtitle: String = ""
    private(set) var currentStatus: LocationStatus = .live
    var onCityResolved: (@MainActor (String) -> Void)?

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
    private let geocoder: any GeocoderProtocol
    private let savedLocationsProvider: (@Sendable () -> [SavedLocation])?
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
        geocodeTimeout: Duration = .seconds(5.0),
        geocoder: any GeocoderProtocol = SystemGeocoder(),
        savedLocationsProvider: (@Sendable () -> [SavedLocation])? = nil
    ) {
        self.clManager = manager
        self.isLocationServicesEnabledProvider = isLocationServicesEnabledProvider
        self.timeoutSleep = timeoutSleep
        self.requestTimeout = requestTimeout
        self.geocodeTimeout = geocodeTimeout
        self.geocoder = geocoder
        self.savedLocationsProvider = savedLocationsProvider
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

    var authorizationError: LocationServiceError {
        if !isLocationServicesEnabled {
            return .servicesDisabled
        }
        switch authorizationStatus {
        case .restricted:
            return .restricted
        case .denied, .notDetermined:
            return .permissionDenied
        default:
            return .permissionDenied
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
            self.currentStatus = .servicesDisabled
            throw LocationServiceError.servicesDisabled
        }

        if authorizationStatus == .denied {
            self.currentStatus = .denied
            throw LocationServiceError.permissionDenied
        }
        if authorizationStatus == .restricted {
            self.currentStatus = .restricted
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

        // Set initial city name without blocking the return of coordinates
        let initialFallback = matchSavedOrPresetCity(for: location) ?? "Current Location"
        self.currentCityName = initialFallback

        // Current-location flow: update currentCityName and currentSubtitle asynchronously
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            let geo = await self.reverseGeocode(location: location)
            self.updateCity(geo.cityName, subtitle: geo.subtitle)
        }

        return location
    }

    private func handleTimeout(for generation: Int) {
        guard self.requestGeneration == generation else {
            // Newer request already in flight or already resolved
            return
        }
        self.currentStatus = .timedOut
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

    func matchSavedOrPresetCity(for location: CLLocation, savedLocations: [SavedLocation]? = nil) -> String? {
        var closestMatch: (name: String, distance: CLLocationDistance)?

        let savedList = savedLocations ?? savedLocationsProvider?() ?? []
        for s in savedList {
            guard !s.isCurrentLocation, let lat = s.latitude, let lon = s.longitude else { continue }
            let sLoc = CLLocation(latitude: lat, longitude: lon)
            let dist = location.distance(from: sLoc)
            if dist <= 25_000 {
                if let closest = closestMatch {
                    if dist < closest.distance {
                        closestMatch = (s.cityName, dist)
                    }
                } else {
                    closestMatch = (s.cityName, dist)
                }
            }
        }

        for p in Self.presetCities {
            let pLoc = CLLocation(latitude: p.lat, longitude: p.lon)
            let dist = location.distance(from: pLoc)
            if dist <= 25_000 {
                if let closest = closestMatch {
                    if dist < closest.distance {
                        closestMatch = (p.name, dist)
                    }
                } else {
                    closestMatch = (p.name, dist)
                }
            }
        }

        return closestMatch?.name
    }

    func updateCity(_ cityName: String, subtitle: String) {
        self.currentCityName = cityName
        self.currentSubtitle = subtitle
        self.onCityResolved?(cityName)
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
                group.addTask { [geocoder] in
                    do {
                        return try await geocoder.reverseGeocode(location: location)
                    } catch {
                        // Geocoder failed or timed out
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
            geocodeCache[cacheKey] = (resolvedCity, subtitle)
        } else if let matchedCity = matchSavedOrPresetCity(for: location) {
            resolvedCity = matchedCity
            if location.distance(from: Self.fallbackCoordinate) < 25_000 {
                subtitle = "Default location · \(Self.fallbackRegionName)"
            } else {
                subtitle = isReducedAccuracy ? "Approximate location" : formatCurrentDateSubtitle()
            }
        } else {
            resolvedCity = "Current Location"
            subtitle = isReducedAccuracy ? "Approximate location" : formatCurrentDateSubtitle()
        }

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
            self.currentStatus = .unavailable
            resumeContinuations(with: .failure(LocationServiceError.invalidCoordinates))
            return
        }

        self.currentStatus = .live
        let previous = self.currentLocation
        self.currentLocation = location

        resumeContinuations(with: .success(location))

        let initialFallback = matchSavedOrPresetCity(for: location) ?? "Current Location"
        self.currentCityName = initialFallback

        Task { @MainActor [weak self] in
            guard let self = self else { return }
            let geo = await self.reverseGeocode(location: location)
            self.updateCity(geo.cityName, subtitle: geo.subtitle)
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
        if let locError = error as? LocationServiceError {
            self.currentStatus = LocationStatus.from(locError)
        } else {
            self.currentStatus = .unavailable
        }
        resumeContinuations(with: .failure(error))
    }
}
