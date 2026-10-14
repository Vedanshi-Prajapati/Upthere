import SwiftUI

public struct LocationsView: View {
    @State private var searchText = ""
    @State private var showCitySearch = false
    @ObservedObject private var locationsManager = SavedLocationsManager.shared
    @State private var editMode: EditMode = .inactive

    public var condition: String?
    public var symbolName: String?
    public var onSelectLocation: ((SavedLocation) -> Void)?
    private let locationService: LocationService

    public init(
        condition: String? = nil,
        symbolName: String? = nil,
        locationService: LocationService? = nil,
        onSelectLocation: ((SavedLocation) -> Void)? = nil
    ) {
        self.condition = condition
        self.symbolName = symbolName
        self.locationService = locationService ?? .shared
        self.onSelectLocation = onSelectLocation
    }

    public var body: some View {
        ZStack {
            WeatherBackgroundView(condition: condition, symbolName: symbolName)

            VStack(spacing: 0) {
                // Navigation bar area
                HStack {
                    Text("Locations")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(.white)
                    Spacer()
                    HStack(spacing: 16) {
                        EditButton()
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.white)
                            .environment(\.editMode, $editMode)
                        Button {
                            showCitySearch = true
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 32, height: 32)
                                .background(Circle().fill(AppTheme.accent))
                        }
                        .accessibilityLabel("Add city")
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 62)
                .padding(.bottom, 14)

                // Search bar
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(AppTheme.textSecondary)
                        .font(.system(size: 16))
                    TextField("", text: $searchText, prompt:
                        Text("Search saved cities").foregroundColor(AppTheme.textSecondary)
                    )
                    .foregroundStyle(.white)
                    .font(.system(size: 16))
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled(true)
                    if !searchText.isEmpty {
                        Button { searchText = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(AppTheme.textSecondary)
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
                .padding(.bottom, 8)

                // List
                List {
                    ForEach(filteredLocations) { location in
                        LocationRowView(
                            location: location,
                            isSelected: locationsManager.selectedLocationId == location.id,
                            onSelect: {
                                onSelectLocation?(location)
                            }
                        )
                        .listRowBackground(Color.clear)
                        .listRowSeparatorTint(Color.white.opacity(0.12))
                        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                    }
                    .onDelete { indexSet in
                        guard editMode == .active else { return }
                        for idx in indexSet {
                            let loc = filteredLocations[idx]
                            if !loc.isCurrentLocation {
                                locationsManager.removeLocation(id: loc.id)
                            }
                        }
                    }
                    .onMove { from, to in
                        guard editMode == .active else { return }
                        // Guard: current location must stay at index 0
                        for sourceIndex in from {
                            if sourceIndex > 0 && to > 0 {
                                locationsManager.moveLocation(fromIndex: sourceIndex, toIndex: to > sourceIndex ? to - 1 : to)
                            }
                        }
                    }

                    // Hint + legal
                    Section {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Tap any city to switch to its live weather. Current location tracks GPS.")
                                .font(.system(size: 13))
                                .foregroundStyle(AppTheme.textSecondary)
                                .lineSpacing(3)
                            Button {
                                if let url = URL(string: "https://weatherkit.apple.com/legal-attribution.html") {
                                    UIApplication.shared.open(url)
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "apple.logo")
                                        .font(.system(size: 11))
                                    Text("Weather · Apple Weather")
                                        .font(.system(size: 12, weight: .medium))
                                }
                                .foregroundStyle(AppTheme.textSecondary)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Apple Weather legal attribution")
                        }
                        .padding(.vertical, 4)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .environment(\.editMode, $editMode)
            }
        }
        .onAppear {
            let subtitle = locationService.currentSubtitle.isEmpty
                ? "Current GPS location"
                : locationService.currentSubtitle
            locationsManager.updateCurrentLocationHeader(
                cityName: locationService.currentCityName,
                subtitle: subtitle
            )
        }
        .sheet(isPresented: $showCitySearch) {
            CitySearchSheet(
                condition: condition,
                symbolName: symbolName
            ) { savedLocation in
                locationsManager.addLocation(savedLocation)
                onSelectLocation?(savedLocation)
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.hidden)
        }
    }

    private var filteredLocations: [SavedLocation] {
        if searchText.isEmpty { return locationsManager.locations }
        return locationsManager.locations.filter {
            $0.cityName.localizedCaseInsensitiveContains(searchText) ||
            $0.regionName.localizedCaseInsensitiveContains(searchText)
        }
    }
}

// MARK: - LocationRowView

private struct LocationRowView: View {
    let location: SavedLocation
    let isSelected: Bool
    var onSelect: (() -> Void)?

    var body: some View {
        Button(action: { onSelect?() }) {
            HStack(spacing: 12) {
                // Left indicator
                if location.isCurrentLocation {
                    Image(systemName: "location.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.accent)
                        .frame(width: 22)
                } else if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(AppTheme.accent)
                        .frame(width: 22)
                } else {
                    Color.clear.frame(width: 22)
                }

                // City info
                VStack(alignment: .leading, spacing: 3) {
                    Text(location.cityName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(subtitleText)
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Condition badge
                if !location.condition.isEmpty && location.condition != "--" {
                    HStack(spacing: 4) {
                        if location.isCurrentLocation {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 6, height: 6)
                        }
                        Text(location.condition)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(location.isCurrentLocation
                                ? Color.green
                                : AppTheme.textSecondary)
                    }
                }
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }

    private var subtitleText: String {
        if location.isCurrentLocation {
            return location.regionName.isEmpty ? "GPS location" : location.regionName
        } else {
            return location.regionName
        }
    }
}

#Preview {
    LocationsView()
}
