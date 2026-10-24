import SwiftUI

/// City search sheet shown when the user taps "+" on the Locations screen.
/// Uses MapKit city searching via MKLocalSearchCompleter and MKLocalSearch.
public struct CitySearchSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: CitySearchViewModel
    @State private var searchText = ""

    public var condition: String?
    public var symbolName: String?
    public var onCitySelected: (SavedLocation) -> Void

    public init(
        condition: String? = nil,
        symbolName: String? = nil,
        searchService: (any CitySearching)? = nil,
        onCitySelected: @escaping (SavedLocation) -> Void
    ) {
        self.condition = condition
        self.symbolName = symbolName
        self._viewModel = State(initialValue: CitySearchViewModel(searchService: searchService ?? MapKitCitySearchService()))
        self.onCitySelected = onCitySelected
    }

    public init(
        viewModel: CitySearchViewModel,
        condition: String? = nil,
        symbolName: String? = nil,
        onCitySelected: @escaping (SavedLocation) -> Void
    ) {
        self.condition = condition
        self.symbolName = symbolName
        self._viewModel = State(initialValue: viewModel)
        self.onCitySelected = onCitySelected
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Drag indicator
            Capsule()
                .fill(Color.white.opacity(0.40))
                .frame(width: 36, height: 5)
                .padding(.top, 10)
                .padding(.bottom, 16)

            // Search bar
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(AppTheme.textSecondary)
                    .font(.body)

                TextField("", text: $searchText, prompt:
                    Text("Search for a city").foregroundColor(AppTheme.textSecondary)
                )
                .foregroundStyle(AppTheme.textPrimary)
                .font(.body)
                .submitLabel(.search)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled(true)
                .onChange(of: searchText) { _, newValue in
                    viewModel.updateSearchText(newValue)
                }

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                        viewModel.updateSearchText("")
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.body)
                            .foregroundStyle(AppTheme.textTertiary)
                    }
                } else {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.textSecondary)
                            .frame(width: 28, height: 28)
                            .background(
                                Circle()
                                    .fill(Color.white.opacity(0.14))
                            )
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.12))
            )
            .padding(.horizontal, 20)
            .padding(.bottom, 24)

            // Content: Empty prompt, loading, no results, or results list
            let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 38))
                        .foregroundStyle(AppTheme.textTertiary)
                        .padding(.bottom, 4)
                    Text("Search for a City")
                        .font(.headline)
                        .foregroundStyle(AppTheme.textPrimary)
                        .accessibilityAddTraits(.isHeader)
                    Text("Search by city name, state, or country.")
                        .font(.footnote)
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 60)
            } else if viewModel.isLoading && viewModel.results.isEmpty {
                VStack(spacing: 16) {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(1.2)
                    Text("Searching cities...")
                        .font(.footnote)
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 60)
            } else if viewModel.results.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.largeTitle)
                        .foregroundStyle(AppTheme.textTertiary)
                    Text("No matching cities found")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(AppTheme.textSecondary)
                        .accessibilityAddTraits(.isHeader)
                    Text("Try searching by city name, state, or country.")
                        .font(.footnote)
                        .foregroundStyle(AppTheme.textTertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 60)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(viewModel.results) { result in
                            Button {
                                select(result: result)
                            } label: {
                                HStack(spacing: 14) {
                                    Image(systemName: "mappin.circle.fill")
                                        .font(.title2)
                                        .foregroundStyle(AppTheme.accent)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(result.title)
                                            .font(.body.weight(.medium))
                                            .foregroundStyle(AppTheme.textPrimary)
                                        if !result.subtitle.isEmpty {
                                            Text(result.subtitle)
                                                .font(.footnote)
                                                .foregroundStyle(AppTheme.textSecondary)
                                        }
                                    }
                                    Spacer()
                                    if viewModel.isResolving {
                                        ProgressView()
                                            .tint(.white)
                                            .scaleEffect(0.8)
                                    }
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 14)
                            }
                            .buttonStyle(.plain)
                            .disabled(viewModel.isResolving)

                            Rectangle()
                                .fill(Color.white.opacity(0.08))
                                .frame(height: 1)
                                .padding(.leading, 56)
                        }
                    }
                }
            }

            Spacer()
        }
        .background(
            WeatherBackgroundView(condition: condition, symbolName: symbolName)
        )
    }

    private func select(result: CitySearchResult) {
        Task {
            do {
                let resolved = try await viewModel.select(result: result)
                let saved = SavedLocation(
                    cityName: resolved.cityName,
                    regionName: resolved.regionName,
                    condition: "Saved",
                    isCurrentLocation: false,
                    latitude: resolved.latitude,
                    longitude: resolved.longitude
                )
                onCitySelected(saved)
                dismiss()
            } catch {
                // If coordinate resolution fails, fallback to title/subtitle without coordinates
                let fallback = SavedLocation(
                    cityName: result.title,
                    regionName: result.subtitle,
                    condition: "Saved",
                    isCurrentLocation: false,
                    latitude: nil,
                    longitude: nil
                )
                onCitySelected(fallback)
                dismiss()
            }
        }
    }
}
