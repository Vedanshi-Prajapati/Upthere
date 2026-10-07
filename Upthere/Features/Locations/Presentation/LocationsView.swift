import SwiftUI

public struct LocationsView: View {
    @State private var searchText = ""
    @State private var showCitySearch = false
    @State private var locations: [SavedLocation] = [
        SavedLocation(cityName: "Ghaziabad", regionName: "Partly Cloudy", condition: "Partly Cloudy", isCurrentLocation: true),
        SavedLocation(cityName: "Delhi",     regionName: "National Capital Territory", condition: "Sunny"),
        SavedLocation(cityName: "Bengaluru", regionName: "Karnataka",                  condition: "Cloudy"),
        SavedLocation(cityName: "Mumbai",    regionName: "Maharashtra",                condition: "Rain"),
    ]

    public var onDone: () -> Void

    public init(onDone: @escaping () -> Void) {
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
                        Text("Search for a city").foregroundColor(AppTheme.textSecondary)
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

                    VStack(spacing: 0) {
                        ForEach(Array(locations.enumerated()), id: \.element.id) { index, location in
                            LocationRow(
                                location: location,
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
                            if index < locations.count - 1 {
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

                Text("Tap the minus to delete. Drag the handle to reorder, or use the arrows. Current location always stays at the top.")
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.leading)
                    .lineSpacing(3)
                    .padding(.horizontal, 20)
                    .padding(.top, 14)

                Spacer()
            }
        }
        .sheet(isPresented: $showCitySearch) {
            CitySearchSheet { cityName in
                let newLocation = SavedLocation(
                    cityName: cityName,
                    regionName: "",
                    condition: "--"
                )
                locations.append(newLocation)
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.hidden)
        }
    }
}

// MARK: - LocationRow

private struct LocationRow: View {
    let location: SavedLocation
    var onDelete: (() -> Void)?
    var onMoveUp: (() -> Void)?
    var onMoveDown: (() -> Void)?

    var body: some View {
        HStack(spacing: 0) {
            // Delete / current indicator
            if location.isCurrentLocation {
                Image(systemName: "location.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
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

            // City info
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

            // Reorder / arrows (non-current only)
            if !location.isCurrentLocation {
                HStack(spacing: 16) {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 15))
                        .foregroundStyle(AppTheme.textTertiary)

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
