import Foundation
import CoreLocation
import MapKit

public enum CitySearchError: LocalizedError, Equatable, Sendable {
    case locationNotFound
    case searchFailed(String)

    public var errorDescription: String? {
        switch self {
        case .locationNotFound:
            return "Unable to find coordinates for the selected city."
        case .searchFailed(let message):
            return "Search failed: \(message)"
        }
    }
}

public struct CitySearchResult: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let subtitle: String

    public init(id: String = UUID().uuidString, title: String, subtitle: String) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
    }
}

public struct ResolvedCityLocation: Equatable, Sendable {
    public let cityName: String
    public let regionName: String
    public let latitude: Double
    public let longitude: Double

    public init(cityName: String, regionName: String, latitude: Double, longitude: Double) {
        self.cityName = cityName
        self.regionName = regionName
        self.latitude = latitude
        self.longitude = longitude
    }
}

public protocol CitySearching: AnyObject, Sendable {
    func searchCompletions(for query: String) async throws -> [CitySearchResult]
    func resolveLocation(for result: CitySearchResult) async throws -> ResolvedCityLocation
}

@MainActor
public final class MapKitCitySearchService: NSObject, CitySearching, MKLocalSearchCompleterDelegate {
    private let completer: MKLocalSearchCompleter
    private var pendingContinuation: CheckedContinuation<[CitySearchResult], Never>?

    public override init() {
        self.completer = MKLocalSearchCompleter()
        super.init()
        self.completer.delegate = self
        self.completer.resultTypes = .address
    }

    public func searchCompletions(for query: String) async throws -> [CitySearchResult] {
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

    public func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let mapped = mapCompletions(completer.results)
        pendingContinuation?.resume(returning: mapped)
        pendingContinuation = nil
    }

    public func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
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

    public func resolveLocation(for result: CitySearchResult) async throws -> ResolvedCityLocation {
        let request = MKLocalSearch.Request()
        let query = result.subtitle.isEmpty ? result.title : "\(result.title), \(result.subtitle)"
        request.naturalLanguageQuery = query
        request.resultTypes = .address

        let search = MKLocalSearch(request: request)
        let response = try await search.start()

        guard let mapItem = response.mapItems.first else {
            throw CitySearchError.locationNotFound
        }

        let coord = mapItem.location.coordinate
        let cityName = mapItem.addressRepresentations?.cityName ?? mapItem.name ?? result.title

        let regionName: String
        if let reg = mapItem.addressRepresentations?.regionName, !reg.isEmpty {
            regionName = reg
        } else if !result.subtitle.isEmpty {
            regionName = result.subtitle
        } else {
            regionName = ""
        }

        return ResolvedCityLocation(
            cityName: cityName,
            regionName: regionName,
            latitude: coord.latitude,
            longitude: coord.longitude
        )
    }
}
