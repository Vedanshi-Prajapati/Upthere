import Testing
import Foundation
import CoreLocation
@testable import Upthere

@Suite("City Search Tests")
struct CitySearchTests {

    final class FakeCitySearchService: CitySearching, @unchecked Sendable {
        var completionsHandler: ((String) async throws -> [CitySearchResult])?
        var resolveHandler: ((CitySearchResult) async throws -> ResolvedCityLocation)?

        var searchCallCount: Int = 0
        var resolveCallCount: Int = 0
        var lastQuery: String?

        func searchCompletions(for query: String) async throws -> [CitySearchResult] {
            searchCallCount += 1
            lastQuery = query
            if let handler = completionsHandler {
                return try await handler(query)
            }
            return []
        }

        func resolveLocation(for result: CitySearchResult) async throws -> ResolvedCityLocation {
            resolveCallCount += 1
            if let handler = resolveHandler {
                return try await handler(result)
            }
            return ResolvedCityLocation(
                cityName: result.title,
                regionName: result.subtitle,
                latitude: 35.6762,
                longitude: 139.6503
            )
        }
    }

    @Test("Results appear when user searches")
    @MainActor
    func searchResultsAppear() async throws {
        let fake = FakeCitySearchService()
        fake.completionsHandler = { query in
            [
                CitySearchResult(id: "1", title: "Tokyo", subtitle: "Japan"),
                CitySearchResult(id: "2", title: "Toronto", subtitle: "Ontario, Canada")
            ]
        }

        let viewModel = CitySearchViewModel(searchService: fake, debounceNanoseconds: 50_000_000)

        #expect(viewModel.results.isEmpty)
        viewModel.updateSearchText("To")

        // Wait for debounce and search completion with timeout
        let deadline = Date().addingTimeInterval(5.0)
        while viewModel.results.isEmpty && Date() < deadline {
            try await Task.sleep(nanoseconds: 20_000_000)
        }

        #expect(viewModel.results.count == 2)
        if viewModel.results.count >= 2 {
            #expect(viewModel.results[0].title == "Tokyo")
            #expect(viewModel.results[0].subtitle == "Japan")
            #expect(viewModel.results[1].title == "Toronto")
            #expect(viewModel.results[1].subtitle == "Ontario, Canada")
        }
        #expect(fake.searchCallCount == 1)
        #expect(fake.lastQuery == "To")
    }

    @Test("Selecting a result resolves coordinates and adds location to SavedLocationsManager")
    @MainActor
    func selectingAddsLocation() async throws {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_search_\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let store = FileLocationStore(fileURL: tempURL)
        let manager = SavedLocationsManager(store: store)

        let fake = FakeCitySearchService()
        fake.resolveHandler = { result in
            ResolvedCityLocation(
                cityName: result.title,
                regionName: result.subtitle,
                latitude: 35.6762,
                longitude: 139.6503
            )
        }

        let viewModel = CitySearchViewModel(searchService: fake, debounceNanoseconds: 0)
        let searchResult = CitySearchResult(id: "tokyo-1", title: "Tokyo", subtitle: "Japan")

        let resolved = try await viewModel.select(result: searchResult)
        #expect(fake.resolveCallCount == 1)
        #expect(resolved.cityName == "Tokyo")
        #expect(resolved.regionName == "Japan")
        #expect(resolved.latitude == 35.6762)
        #expect(resolved.longitude == 139.6503)

        let saved = SavedLocation(
            cityName: resolved.cityName,
            regionName: resolved.regionName,
            condition: "Saved",
            isCurrentLocation: false,
            latitude: resolved.latitude,
            longitude: resolved.longitude
        )

        manager.addLocation(saved)

        let added = manager.locations.first(where: { $0.cityName == "Tokyo" })
        #expect(added != nil)
        #expect(added?.regionName == "Japan")
        #expect(added?.latitude == 35.6762)
        #expect(added?.longitude == 139.6503)
    }

    @Test("Stale search results are dropped when a newer search starts")
    @MainActor
    func staleSearchResultsDropped() async throws {
        let fake = FakeCitySearchService()
        final class SearchTracker: @unchecked Sendable {
            var slowSearchStarted = false
            var slowSearchFinished = false
        }
        let tracker = SearchTracker()

        fake.completionsHandler = { query in
            if query == "SlowCity" {
                tracker.slowSearchStarted = true
                // Simulate slow network search (shrunk from 200ms)
                try await Task.sleep(nanoseconds: 30_000_000)
                tracker.slowSearchFinished = true
                return [CitySearchResult(id: "slow", title: "SlowCity", subtitle: "SlowRegion")]
            } else if query == "FastCity" {
                return [CitySearchResult(id: "fast", title: "FastCity", subtitle: "FastRegion")]
            }
            return []
        }

        // 10ms debounce for rapid testing
        let viewModel = CitySearchViewModel(searchService: fake, debounceNanoseconds: 10_000_000)

        // Start slow search
        viewModel.updateSearchText("SlowCity")

        // Wait just enough for debounce to fire and SlowCity search to begin executing
        let startDeadline = Date().addingTimeInterval(2.0)
        while !tracker.slowSearchStarted && Date() < startDeadline {
            try await Task.sleep(nanoseconds: 2_000_000)
        }

        // Before slow search completes, start FastCity search
        viewModel.updateSearchText("FastCity")

        // Wait for FastCity search and slow search background continuation to finish
        let deadline = Date().addingTimeInterval(5.0)
        while (viewModel.results.isEmpty || !tracker.slowSearchFinished) && Date() < deadline {
            try await Task.sleep(nanoseconds: 2_000_000)
        }

        // SlowCity results must have been dropped, only FastCity results present
        #expect(viewModel.results.count == 1)
        #expect(viewModel.results.first?.title == "FastCity")
        #expect(viewModel.results.first?.subtitle == "FastRegion")
    }

    @Test("Typing within debounce window cancels previous search")
    @MainActor
    func typingWithinDebounceCancelsPrevious() async throws {
        let fake = FakeCitySearchService()
        fake.completionsHandler = { query in
            [CitySearchResult(id: query, title: query, subtitle: "Region")]
        }

        let viewModel = CitySearchViewModel(searchService: fake, debounceNanoseconds: 100_000_000)

        // Type rapidly
        viewModel.updateSearchText("P")
        try await Task.sleep(nanoseconds: 30_000_000)
        viewModel.updateSearchText("Po")
        try await Task.sleep(nanoseconds: 30_000_000)
        viewModel.updateSearchText("Por")
        try await Task.sleep(nanoseconds: 30_000_000)
        viewModel.updateSearchText("Port")

        // Wait for final debounce to trigger
        let deadline = Date().addingTimeInterval(5.0)
        while viewModel.results.isEmpty && Date() < deadline {
            try await Task.sleep(nanoseconds: 20_000_000)
        }

        // Only the final query should have been dispatched to searchCompletions
        #expect(fake.searchCallCount == 1)
        #expect(fake.lastQuery == "Port")
        #expect(viewModel.results.first?.title == "Port")
    }

    @Test("Identical city names are disambiguated by region and both can be added if > 5km apart")
    @MainActor
    func identicalCityNamesDisambiguationAndDuplicateDetection() async throws {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_disambig_\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let store = FileLocationStore(fileURL: tempURL)
        let manager = SavedLocationsManager(store: store)

        let fake = FakeCitySearchService()
        fake.completionsHandler = { query in
            if query.localizedCaseInsensitiveContains("Portland") {
                return [
                    CitySearchResult(id: "portland-or", title: "Portland", subtitle: "Oregon, USA"),
                    CitySearchResult(id: "portland-me", title: "Portland", subtitle: "Maine, USA")
                ]
            }
            return []
        }

        let viewModel = CitySearchViewModel(searchService: fake, debounceNanoseconds: 0)
        viewModel.updateSearchText("Portland")

        let deadline = Date().addingTimeInterval(5.0)
        while viewModel.results.isEmpty && Date() < deadline {
            try await Task.sleep(nanoseconds: 20_000_000)
        }

        #expect(viewModel.results.count == 2)
        if viewModel.results.count >= 2 {
            #expect(viewModel.results[0].title == viewModel.results[1].title)
            #expect(viewModel.results[0].subtitle != viewModel.results[1].subtitle)

            // Add Portland, OR
            let orLoc = SavedLocation(
                cityName: viewModel.results[0].title,
                regionName: viewModel.results[0].subtitle,
                condition: "Saved",
                isCurrentLocation: false,
                latitude: 45.5152,
                longitude: -122.6784
            )
            manager.addLocation(orLoc)
            #expect(manager.locations.contains(where: { $0.regionName == "Oregon, USA" }))

            // Add Portland, ME (identical name, ~4100 km apart)
            let meLoc = SavedLocation(
                cityName: viewModel.results[1].title,
                regionName: viewModel.results[1].subtitle,
                condition: "Saved",
                isCurrentLocation: false,
                latitude: 43.6615,
                longitude: -70.2553
            )
            manager.addLocation(meLoc)
            #expect(manager.locations.contains(where: { $0.regionName == "Maine, USA" }))
        }

        // Try adding a location within 5km of Portland, OR (~1.2 km away)
        let nearOR = SavedLocation(
            cityName: "Portland Downtown",
            regionName: "Oregon, USA",
            condition: "Saved",
            isCurrentLocation: false,
            latitude: 45.5200,
            longitude: -122.6820
        )
        let countBefore = manager.locations.count
        #expect(manager.isDuplicate(nearOR))
        manager.addLocation(nearOR)
        #expect(manager.locations.count == countBefore, "Duplicate within 5km must be rejected")
    }
}
