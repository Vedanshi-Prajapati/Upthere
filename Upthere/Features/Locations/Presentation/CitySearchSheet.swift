import SwiftUI

/// City search sheet shown when the user taps "+" on the Locations screen.
/// Displays a search bar and searchable city database with coordinates.
public struct CitySearchSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    public struct CityData: Hashable {
        public let name: String
        public let region: String
        public let latitude: Double
        public let longitude: Double
    }

    private let allCities: [CityData] = [
        // Global Capitals and Major Hubs
        CityData(name: "Sydney", region: "New South Wales, Australia", latitude: -33.8688, longitude: 151.2093),
        CityData(name: "Cupertino", region: "California, USA", latitude: 37.3230, longitude: -122.0322),
        CityData(name: "San Francisco", region: "California, USA", latitude: 37.7749, longitude: -122.4194),
        CityData(name: "New York", region: "New York, USA", latitude: 40.7128, longitude: -74.0060),
        CityData(name: "London", region: "United Kingdom", latitude: 51.5074, longitude: -0.1278),
        CityData(name: "Tokyo", region: "Japan", latitude: 35.6762, longitude: 139.6503),
        CityData(name: "Paris", region: "France", latitude: 48.8566, longitude: 2.3522),
        CityData(name: "Berlin", region: "Germany", latitude: 52.5200, longitude: 13.4050),
        CityData(name: "Dubai", region: "United Arab Emirates", latitude: 25.2048, longitude: 55.2708),
        CityData(name: "Singapore", region: "Singapore", latitude: 1.3521, longitude: 103.8198),
        // Disambiguation: Cities with duplicate/similar names
        CityData(name: "Portland", region: "Oregon, USA", latitude: 45.5152, longitude: -122.6784),
        CityData(name: "Portland", region: "Maine, USA", latitude: 43.6615, longitude: -70.2553),
        CityData(name: "Cambridge", region: "Cambridgeshire, United Kingdom", latitude: 52.2053, longitude: 0.1218),
        CityData(name: "Cambridge", region: "Massachusetts, USA", latitude: 42.3736, longitude: -71.1097),
        CityData(name: "Springfield", region: "Illinois, USA", latitude: 39.7817, longitude: -89.6501),
        CityData(name: "Springfield", region: "Missouri, USA", latitude: 37.2090, longitude: -93.2923),
        // Regional Hubs
        CityData(name: "Delhi", region: "National Capital Territory, India", latitude: 28.6139, longitude: 77.2090),
        CityData(name: "Ghaziabad", region: "Uttar Pradesh, India (Default fallback)", latitude: 28.6692, longitude: 77.4538),
        CityData(name: "Mumbai", region: "Maharashtra, India", latitude: 19.0760, longitude: 72.8777),
        CityData(name: "Bengaluru", region: "Karnataka, India", latitude: 12.9716, longitude: 77.5946),
        CityData(name: "Pune", region: "Maharashtra, India", latitude: 18.5204, longitude: 73.8567),
        CityData(name: "Jaipur", region: "Rajasthan, India", latitude: 26.9124, longitude: 75.7873),
        CityData(name: "Chennai", region: "Tamil Nadu, India", latitude: 13.0827, longitude: 80.2707),
        CityData(name: "Kolkata", region: "West Bengal, India", latitude: 22.5726, longitude: 88.3639),
        CityData(name: "Hyderabad", region: "Telangana, India", latitude: 17.3850, longitude: 78.4867)
    ]

    public var condition: String?
    public var symbolName: String?
    public var onCitySelected: (SavedLocation) -> Void

    public init(
        condition: String? = nil,
        symbolName: String? = nil,
        onCitySelected: @escaping (SavedLocation) -> Void
    ) {
        self.condition = condition
        self.symbolName = symbolName
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
                .foregroundStyle(.white)
                .font(.body)
                .submitLabel(.search)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled(true)

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
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

            // Suggestions or Results
            let sanitizedQuery = sanitizedSearchQuery
            if sanitizedQuery.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Suggestions")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(allCities.prefix(8), id: \.self) { city in
                                Button {
                                    select(city: city)
                                } label: {
                                    Text(city.name)
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(.primary)
                                        .padding(.horizontal, 18)
                                        .padding(.vertical, 10)
                                        .background(
                                            Capsule()
                                                .fill(.white.opacity(0.88))
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
            } else {
                // Search results
                let results = filteredCities
                if results.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.largeTitle)
                            .foregroundStyle(AppTheme.textTertiary)
                        Text("No matching cities found")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(AppTheme.textSecondary)
                        Text("Try searching by city name, state, or country.")
                            .font(.footnote)
                            .foregroundStyle(AppTheme.textTertiary)
                    }
                    .padding(.top, 60)
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(results, id: \.self) { city in
                                Button {
                                    select(city: city)
                                } label: {
                                    HStack(spacing: 14) {
                                        Image(systemName: "mappin.circle.fill")
                                            .font(.title2)
                                            .foregroundStyle(AppTheme.accent)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(city.name)
                                                .font(.body.weight(.medium))
                                                .foregroundStyle(.white)
                                            Text(city.region)
                                                .font(.footnote)
                                                .foregroundStyle(AppTheme.textSecondary)
                                        }
                                        Spacer()
                                    }
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 14)
                                }
                                .buttonStyle(.plain)

                                Rectangle()
                                    .fill(Color.white.opacity(0.08))
                                    .frame(height: 1)
                                    .padding(.leading, 56)
                            }
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

    private var sanitizedSearchQuery: String {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return String(trimmed.prefix(100))
    }

    private func select(city: CityData) {
        let saved = SavedLocation(
            cityName: city.name,
            regionName: city.region,
            condition: "Saved",
            isCurrentLocation: false,
            latitude: city.latitude,
            longitude: city.longitude
        )
        onCitySelected(saved)
        dismiss()
    }

    private var filteredCities: [CityData] {
        let query = sanitizedSearchQuery
        guard !query.isEmpty else { return [] }
        return allCities.filter {
            $0.name.localizedCaseInsensitiveContains(query) ||
            $0.region.localizedCaseInsensitiveContains(query)
        }
    }
}
