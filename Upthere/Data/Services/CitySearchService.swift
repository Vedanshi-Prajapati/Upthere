import Foundation
import CoreLocation
@preconcurrency import MapKit

struct MapItemData: Sendable {
    let name: String?
    let locality: String?
    let region: String?
    let coordinate: CLLocationCoordinate2D

    init(name: String?, locality: String?, region: String?, coordinate: CLLocationCoordinate2D) {
        self.name = name
        self.locality = locality
        self.region = region
        self.coordinate = coordinate
    }
}

enum CitySearchError: LocalizedError, Equatable, Sendable {
    case locationNotFound
    case searchFailed(String)

    var errorDescription: String? {
        switch self {
        case .locationNotFound:
            return "Unable to find coordinates for the selected city."
        case .searchFailed(let message):
            return "Search failed: \(message)"
        }
    }
}

struct CitySearchResult: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let subtitle: String

    init(id: String = UUID().uuidString, title: String, subtitle: String) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
    }
}

struct ResolvedCityLocation: Equatable, Sendable {
    let cityName: String
    let regionName: String
    let latitude: Double
    let longitude: Double

    init(cityName: String, regionName: String, latitude: Double, longitude: Double) {
        self.cityName = cityName
        self.regionName = regionName
        self.latitude = latitude
        self.longitude = longitude
    }
}

protocol CitySearching: AnyObject, Sendable {
    func searchCompletions(for query: String) async throws -> [CitySearchResult]
    func resolveLocation(for result: CitySearchResult) async throws -> ResolvedCityLocation
}

@MainActor
final class MapKitCitySearchService: NSObject, CitySearching, MKLocalSearchCompleterDelegate {
    private let completer: MKLocalSearchCompleter
    private var pendingContinuation: CheckedContinuation<[CitySearchResult], Never>?

    override init() {
        self.completer = MKLocalSearchCompleter()
        super.init()
        self.completer.delegate = self
        self.completer.resultTypes = .address
    }

    func searchCompletions(for query: String) async throws -> [CitySearchResult] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            completer.queryFragment = ""
            return []
        }

        // If the query fragment is identical and already resolved, return existing filtered results
        if completer.queryFragment == trimmed && !completer.isSearching && !completer.results.isEmpty {
            return mapCompletions(completer.results)
        }

        // Cancel previous pending continuation with empty results
        pendingContinuation?.resume(returning: [])
        pendingContinuation = nil

        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                self.pendingContinuation = continuation
                self.completer.queryFragment = trimmed
            }
        } onCancel: {
            Task { @MainActor in
                if self.pendingContinuation != nil {
                    self.pendingContinuation?.resume(returning: [])
                    self.pendingContinuation = nil
                }
            }
        }
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let mapped = mapCompletions(completer.results)
        pendingContinuation?.resume(returning: mapped)
        pendingContinuation = nil
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        pendingContinuation?.resume(returning: [])
        pendingContinuation = nil
    }

    private func mapCompletions(_ results: [MKLocalSearchCompletion]) -> [CitySearchResult] {
        results.compactMap { completion -> CitySearchResult? in
            let title = completion.title.trimmingCharacters(in: .whitespacesAndNewlines)
            let subtitle = completion.subtitle.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty else { return nil }
            return CitySearchResult(title: title, subtitle: subtitle)
        }
    }

    func resolveLocation(for result: CitySearchResult) async throws -> ResolvedCityLocation {
        let request = MKLocalSearch.Request()
        let query = result.subtitle.isEmpty ? result.title : "\(result.title), \(result.subtitle)"
        request.naturalLanguageQuery = query
        request.resultTypes = .address

        let search = MKLocalSearch(request: request)
        let response = try await search.start()

        guard let mapItem = response.mapItems.first else {
            throw CitySearchError.locationNotFound
        }

        // Convert MKMapItem result to a plain Sendable struct inside callback before returning
        let itemData = MapItemData(
            name: mapItem.name,
            locality: mapItem.addressRepresentations?.cityName ?? mapItem.placemark.locality,
            region: mapItem.addressRepresentations?.regionName ?? mapItem.placemark.administrativeArea,
            coordinate: mapItem.location.coordinate
        )

        let cityName = itemData.locality ?? itemData.name ?? result.title

        let regionName: String
        if let reg = itemData.region, !reg.isEmpty {
            regionName = reg
        } else if !result.subtitle.isEmpty {
            regionName = result.subtitle
        } else {
            regionName = ""
        }

        return ResolvedCityLocation(
            cityName: cityName,
            regionName: regionName,
            latitude: itemData.coordinate.latitude,
            longitude: itemData.coordinate.longitude
        )
    }
}
