import SwiftUI

public struct LocationsView: View {
    @State private var searchText = ""
    @State private var showCitySearch = false
    @State private var locations: [SavedLocation] = [
        SavedLocation(cityName: LocationService.shared.currentCityName, regionName: "Current GPS location", condition: "Live", isCurrentLocation: true),
        SavedLocation(cityName: "Sydney",    regionName: "New South Wales, Australia", condition: "Sunny", isCurrentLocation: false, latitude: -33.8688, longitude: 151.2093),
        SavedLocation(cityName: "Cupertino", regionName: "California, USA",            condition: "Clear", isCurrentLocation: false, latitude: 37.3230,  longitude: -122.0322),
        SavedLocation(cityName: "London",    regionName: "United Kingdom",             condition: "Cloudy", isCurrentLocation: false, latitude: 51.5074,  longitude: -0.1278),
        SavedLocation(cityName: "Tokyo",     regionName: "Japan",                      condition: "Rain",  isCurrentLocation: false, latitude: 35.6762,  longitude: 139.6503),
        SavedLocation(cityName: "Delhi",     regionName: "National Capital Territory", condition: "Haze",  isCurrentLocation: false, latitude: 28.6139,  longitude: 77.2090),
    ]

    public var onSelectLocation: ((SavedLocation) -> Void)?
    public var onDone: () -> Void

    public init(
        onSelectLocation: ((SavedLocation) -> Void)? = nil,
        onDone: @escaping () -> Void
    ) {
        self.onSelectLocation = onSelectLocation
        self.onDone = onDone
    }

    public var body: some View {
        ZStack {
            AppTheme.backgroundGradient.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Button(action: onDone) {
                        Text("Done")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(Color.white.opacity(0.14))
                            )
                    }
                    Spacer()
                    Button {
                        showCitySearch = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(AppTheme.accent))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 62)
                .padding(.bottom, 16)

                Text("Locations")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 14)

                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(AppTheme.textSecondary)
                        .font(.system(size: 16))
                    TextField("", text: $searchText, prompt:
                        Text("Search saved cities").foregroundColor(AppTheme.textSecondary)
                    )
                    .foregroundStyle(.white)
                    .font(.system(size: 16))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 13)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.12))
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 24)

                VStack(alignment: .leading, spacing: 0) {
                    Text("Saved")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 10)

                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(Array(filteredLocations.enumerated()), id: \.element.id) { index, location in
                                LocationRow(
                                    location: location,
                                    onSelect: {
                                        onSelectLocation?(location)
                                    },
                                    onDelete: location.isCurrentLocation ? nil : {
                                        locations.removeAll { $0.id == location.id }
                                    },
                                    onMoveUp: index > 1 ? {
                                        locations.swapAt(index, index - 1)
                                    } : nil,
                                    onMoveDown: (index < locations.count - 1 && index > 0) ? {
                                        locations.swapAt(index, index + 1)
                                    } : nil
                                )
                                if index < filteredLocations.count - 1 {
                                    Rectangle()
                                        .fill(Color.white.opacity(0.10))
                                        .frame(height: 1)
                                        .padding(.leading, location.isCurrentLocation ? 16 : 56)
                                }
                            }
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(AppTheme.cardGlass)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .padding(.horizontal, 20)
                    }
                }

                Text("Tap any city to switch to its live weather. Current location tracks GPS.")
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.leading)
                    .lineSpacing(3)
                    .padding(.horizontal, 20)
                    .padding(.top, 14)

                Spacer()
            }
        }
        .onAppear {
            // Update the top location's city name to match current GPS location
            if !locations.isEmpty && locations[0].isCurrentLocation {
                locations[0] = SavedLocation(
                    id: locations[0].id,
                    cityName: LocationService.shared.currentCityName,
                    regionName: LocationService.shared.currentSubtitle.isEmpty ? "Current GPS location" : LocationService.shared.currentSubtitle,
                    condition: "Live",
                    isCurrentLocation: true
                )
            }
        }
        .sheet(isPresented: $showCitySearch) {
            CitySearchSheet { savedLocation in
                locations.append(savedLocation)
                onSelectLocation?(savedLocation)
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.hidden)
        }
    }

    private var filteredLocations: [SavedLocation] {
        if searchText.isEmpty { return locations }
        return locations.filter {
            $0.cityName.localizedCaseInsensitiveContains(searchText) ||
            $0.regionName.localizedCaseInsensitiveContains(searchText)
        }
    }
}

// MARK: - LocationRow

private struct LocationRow: View {
    let location: SavedLocation
    var onSelect: (() -> Void)?
    var onDelete: (() -> Void)?
    var onMoveUp: (() -> Void)?
    var onMoveDown: (() -> Void)?

    var body: some View {
        HStack(spacing: 0) {
            // Delete / current indicator
            if location.isCurrentLocation {
                Image(systemName: "location.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.accent)
                    .frame(width: 40)
            } else {
                Button(action: { onDelete?() }) {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(.red)
                }
                .frame(width: 40)
                .disabled(onDelete == nil)
            }

            // City info (tappable to switch active city)
            Button(action: { onSelect?() }) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(location.cityName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(location.isCurrentLocation
                         ? "\(location.cityName) · \(location.condition)"
                         : "\(location.regionName) · \(location.condition)")
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            // Reorder / arrows (non-current only)
            if !location.isCurrentLocation {
                HStack(spacing: 16) {
                    Button(action: { onMoveUp?() }) {
                        Image(systemName: "chevron.up")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(onMoveUp != nil ? AppTheme.textSecondary : AppTheme.textTertiary)
                    }
                    .disabled(onMoveUp == nil)

                    Button(action: { onMoveDown?() }) {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(onMoveDown != nil ? AppTheme.textSecondary : AppTheme.textTertiary)
                    }
                    .disabled(onMoveDown == nil)
                }
                .padding(.trailing, 4)
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 14)
    }
}

#Preview {
    LocationsView(onDone: {})
}
