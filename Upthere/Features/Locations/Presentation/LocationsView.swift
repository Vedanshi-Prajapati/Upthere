import SwiftUI

public struct LocationsView: View {
    @State private var searchText = ""
    @State private var showCitySearch = false
    @ObservedObject private var locationsManager = SavedLocationsManager.shared

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
            WeatherBackgroundView(type: .defaultTheme)

            VStack(spacing: 0) {
                HStack {
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
                                        locationsManager.removeLocation(id: location.id)
                                    },
                                    onMoveUp: index > 1 ? {
                                        locationsManager.moveLocation(fromIndex: index, toIndex: index - 1)
                                    } : nil,
                                    onMoveDown: (index < filteredLocations.count - 1 && index > 0) ? {
                                        locationsManager.moveLocation(fromIndex: index, toIndex: index + 1)
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

                        // Hint text — inside scroll so it's never clipped by the tab bar
                        Text("Tap any city to switch to its live weather. Current location tracks GPS.")
                            .font(.system(size: 13))
                            .foregroundStyle(AppTheme.textSecondary)
                            .multilineTextAlignment(.leading)
                            .lineSpacing(3)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 20)
                            .padding(.top, 14)
                            .padding(.bottom, 120) // clears custom tab bar (64pt) + 36pt bottom padding + buffer
                    }
                }
            }
        }
        .onAppear {
            let subtitle = LocationService.shared.currentSubtitle.isEmpty ? "Current GPS location" : LocationService.shared.currentSubtitle
            locationsManager.updateCurrentLocationHeader(
                cityName: LocationService.shared.currentCityName,
                subtitle: subtitle
            )
        }
        .sheet(isPresented: $showCitySearch) {
            CitySearchSheet { savedLocation in
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
                    Text(subtitleText(for: location))
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

    private func subtitleText(for location: SavedLocation) -> String {
        let hasCondition = !location.condition.isEmpty && location.condition != "--"
        if location.isCurrentLocation {
            return hasCondition ? "\(location.cityName) · \(location.condition)" : location.cityName
        } else {
            return hasCondition ? "\(location.regionName) · \(location.condition)" : location.regionName
        }
    }
}

#Preview {
    LocationsView(onDone: {})
}
