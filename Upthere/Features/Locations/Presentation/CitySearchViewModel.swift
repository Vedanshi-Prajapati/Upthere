import Foundation
import Observation

@Observable
@MainActor
final class CitySearchViewModel {
    var searchText: String = "" {
        didSet {
            guard searchText != oldValue else { return }
            handleSearchTextChanged(searchText)
        }
    }

    private(set) var results: [CitySearchResult] = []
    private(set) var isLoading: Bool = false
    private(set) var isResolving: Bool = false
    private(set) var errorMessage: String? = nil

    private let searchService: any CitySearching
    private let debounceNanoseconds: UInt64
    private var activeSearchTask: Task<Void, Never>?
    private var currentSearchId: UUID = UUID()

    init(
        searchService: (any CitySearching)? = nil,
        debounceNanoseconds: UInt64 = 300_000_000 // 300 ms
    ) {
        self.searchService = searchService ?? MapKitCitySearchService()
        self.debounceNanoseconds = debounceNanoseconds
    }

    func updateSearchText(_ text: String) {
        searchText = text
    }

    func handleSearchTextChanged(_ newText: String) {
        // 1. Cancel previous stale search task
        activeSearchTask?.cancel()
        activeSearchTask = nil

        let trimmed = newText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            results = []
            isLoading = false
            errorMessage = nil
            return
        }

        isLoading = true
        errorMessage = nil

        let searchId = UUID()
        self.currentSearchId = searchId

        let debounceDelay = self.debounceNanoseconds

        activeSearchTask = Task { [weak self] in
            // 2. Debounce typing by 300 ms
            if debounceDelay > 0 {
                do {
                    try await Task.sleep(nanoseconds: debounceDelay)
                } catch {
                    // Task was cancelled during debounce sleep
                    return
                }
            }

            guard !Task.isCancelled else { return }
            guard let self = self, self.currentSearchId == searchId else { return }

            do {
                let completions = try await self.searchService.searchCompletions(for: trimmed)

                // 3. Drop stale search results if searchId changed or task was cancelled
                guard !Task.isCancelled, self.currentSearchId == searchId else { return }

                self.results = completions
                self.isLoading = false
            } catch {
                guard !Task.isCancelled, self.currentSearchId == searchId else { return }
                self.errorMessage = error.localizedDescription
                self.results = []
                self.isLoading = false
            }
        }
    }

    func select(result: CitySearchResult) async throws -> ResolvedCityLocation {
        isResolving = true
        defer { isResolving = false }
        return try await searchService.resolveLocation(for: result)
    }
}
