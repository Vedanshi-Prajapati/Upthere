import SwiftUI
import CoreLocation

struct LocationsView: View {
    @Environment(\.weatherFormatter) private var weatherFormatter
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @State private var searchText = ""
    @State private var showCitySearch = false
    @ObservedObject private var locationsManager: SavedLocationsManager
    @State private var editMode: EditMode = .inactive

    @State private var weatherSummaries: [UUID: (temperature: Double, symbolName: String)] = [:]

    var condition: String?
    var symbolName: String?
    var onSelectLocation: ((SavedLocation) -> Void)?
    private let locationService: LocationService
    private let weatherRepository: any WeatherRepository
    private let cacheManager: WeatherCacheManager
    private let citySearchService: any CitySearching

    init(
        condition: String? = nil,
        symbolName: String? = nil,
        locationsManager: SavedLocationsManager? = nil,
        locationService: LocationService? = nil,
        weatherRepository: (any WeatherRepository)? = nil,
        cacheManager: WeatherCacheManager? = nil,
        citySearchService: (any CitySearching)? = nil,
        onSelectLocation: ((SavedLocation) -> Void)? = nil
    ) {
        self.condition = condition
        self.symbolName = symbolName
        self.locationsManager = locationsManager ?? SavedLocationsManager()
        let loc = locationService ?? LocationService()
        self.locationService = loc
        self.weatherRepository = weatherRepository ?? WeatherKitWeatherRepository(locationService: loc)
        self.cacheManager = cacheManager ?? .shared
        self.citySearchService = citySearchService ?? MapKitCitySearchService()
        self.onSelectLocation = onSelectLocation
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                WeatherBackgroundView(condition: condition, symbolName: symbolName)

                VStack(spacing: 0) {
                    if let error = locationsManager.saveErrorMessage {
                        HStack(spacing: 10) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.yellow)
                            Text(error)
                                .font(AppFont.caption)
                                .foregroundStyle(AppTheme.textPrimary)
                            Spacer()
                            Button {
                                locationsManager.saveErrorMessage = nil
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.red.opacity(0.2))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.red.opacity(0.35), lineWidth: 1)
                                )
                        )
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .animation(.easeInOut, value: locationsManager.saveErrorMessage)
                    }

                    List {
                        ForEach(filteredLocations) { location in
                        LocationRowView(
                            location: location,
                            isSelected: isLocationSelected(location),
                            weatherSummary: weatherSummaries[location.id],
                            onSelect: {
                                onSelectLocation?(location)
                            }
                        )
                        .listRowBackground(Color.clear)
                        .listRowSeparatorTint(Color.white.opacity(0.12))
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                        .moveDisabled(location.isCurrentLocation)
                        .deleteDisabled(location.isCurrentLocation)
                    }
                    .onDelete { indexSet in
                        for idx in indexSet {
                            guard idx < filteredLocations.count else { continue }
                            let loc = filteredLocations[idx]
                            if !loc.isCurrentLocation {
                                locationsManager.removeLocation(id: loc.id)
                            }
                        }
                    }
                    .onMove { fromOffsets, toOffset in
                        locationsManager.moveLocation(fromOffsets: fromOffsets, toOffset: toOffset, within: filteredLocations)
                    }

                    // Empty state when only Current location exists and not searching
                    if !locationsManager.locations.contains(where: { !$0.isCurrentLocation }) && searchText.isEmpty {
                        Section {
                            VStack(spacing: 12) {
                                Image(systemName: "building.2.crop.circle")
                                    .font(.system(size: 38))
                                    .foregroundStyle(AppTheme.textSecondary)

                                Text("Add your first city")
                                    .font(AppFont.headline)
                                    .foregroundStyle(AppTheme.textPrimary)

                                Text("Search and save cities to track their weather and quickly switch between them.")
                                    .font(AppFont.subheadline)
                                    .foregroundStyle(AppTheme.textSecondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 16)

                                Button {
                                    showCitySearch = true
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "plus")
                                        Text("Add City")
                                    }
                                    .font(AppFont.subheadlineSemibold)
                                    .foregroundStyle(Color.black)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .background(Capsule().fill(Color.white))
                                }
                                .padding(.top, 4)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                            .padding(.horizontal, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.white.opacity(0.06))
                            )
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                        }
                    }

                    // Hint + legal
                    Section {
                        VStack(alignment: .center, spacing: 8) {
                            Text("Tap any city to switch to its live weather.")
                                .font(.footnote)
                                .foregroundStyle(AppTheme.textSecondary)

                            AttributionView()
                                .padding(.top, 4)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .padding(.bottom, AppTheme.tabBarClearance)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }
                }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .searchable(text: $searchText, prompt: "Search saved cities")
                    .environment(\.editMode, $editMode)
                }
            }
            .navigationTitle("Locations")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Group {
                        if reduceTransparency {
                            HStack(spacing: 2) {
                                EditButton()
                                    .font(AppFont.subheadlineSemibold)
                                    .foregroundStyle(AppTheme.textPrimary)
                                    .padding(.horizontal, 8)
                                    .frame(minHeight: 32)

                                Button {
                                    showCitySearch = true
                                } label: {
                                    Image(systemName: "plus")
                                        .font(AppFont.subheadlineSemibold)
                                        .foregroundStyle(AppTheme.textPrimary)
                                        .frame(minWidth: 30, minHeight: 32)
                                }
                                .accessibilityLabel("Add city")
                            }
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color(white: 0.18), in: Capsule())
                        } else {
                            GlassEffectContainer(spacing: 2) {
                                HStack(spacing: 2) {
                                    EditButton()
                                        .font(AppFont.subheadlineSemibold)
                                        .foregroundStyle(AppTheme.textPrimary)
                                        .padding(.horizontal, 8)
                                        .frame(minHeight: 32)

                                    Button {
                                        showCitySearch = true
                                    } label: {
                                        Image(systemName: "plus")
                                            .font(AppFont.subheadlineSemibold)
                                            .foregroundStyle(AppTheme.textPrimary)
                                            .frame(minWidth: 30, minHeight: 32)
                                    }
                                    .accessibilityLabel("Add city")
                                }
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .environment(\.colorScheme, .dark)
        .task {
            updateCurrentLocationHeader()
            await fetchWeatherForLocations(locationsManager.locations)
        }
        .onChange(of: locationsManager.locations) { _, newLocations in
            Task {
                await fetchWeatherForLocations(newLocations)
            }
        }
        .sheet(isPresented: $showCitySearch) {
            CitySearchSheet(
                condition: condition,
                symbolName: symbolName,
                searchService: citySearchService
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

    private func isLocationSelected(_ location: SavedLocation) -> Bool {
        if location.isCurrentLocation {
            return locationsManager.selectedLocationId == nil || locationsManager.selectedLocationId == location.id
        }
        return locationsManager.selectedLocationId == location.id
    }

    private func updateCurrentLocationHeader() {
        let subtitle = locationService.currentSubtitle.isEmpty
            ? "Current GPS location"
            : locationService.currentSubtitle
        locationsManager.updateCurrentLocationHeader(
            cityName: locationService.currentCityName,
            subtitle: subtitle
        )
    }

    // MARK: - Concurrent Per-City Weather Fetching (Max 3 concurrent requests, with Cache)
    private func fetchWeatherForLocations(_ locations: [SavedLocation]) async {
        // Step 1: Pre-populate any cached records immediately
        for loc in locations {
            if let cached = loadCachedSummary(for: loc) {
                weatherSummaries[loc.id] = (cached.weather.temperature, cached.weather.weatherSymbolName)
            }
        }

        // Step 2: Determine which locations need network fetch
        let needed = locations.filter { loc in
            guard let cached = loadCachedSummary(for: loc) else { return true }
            return !cached.isFresh
        }

        guard !needed.isEmpty else { return }

        // Step 3: Concurrency pool with at most 3 concurrent requests
        await withTaskGroup(of: (UUID, (Double, String)?).self) { group in
            var iterator = needed.makeIterator()

            for _ in 0..<3 {
                if let next = iterator.next() {
                    group.addTask {
                        let res = await self.fetchSingleWeather(for: next)
                        return (next.id, res)
                    }
                }
            }

            for await (id, res) in group {
                if let res = res {
                    self.weatherSummaries[id] = res
                }
                if let next = iterator.next() {
                    group.addTask {
                        let res = await self.fetchSingleWeather(for: next)
                        return (next.id, res)
                    }
                }
            }
        }
    }

    private func loadCachedSummary(for location: SavedLocation) -> CachedWeatherRecord? {
        let coord: (lat: Double, lon: Double)? = {
            if let lat = location.latitude, let lon = location.longitude {
                return (lat, lon)
            }
            if location.isCurrentLocation {
                let currentCoord = locationService.currentLocation?.coordinate ?? LocationService.fallbackCoordinate.coordinate
                return (currentCoord.latitude, currentCoord.longitude)
            }
            return nil
        }()

        let key = cacheManager.cacheKey(for: location.cityName, coordinate: coord)
        return cacheManager.load(key: key, allowExpired: true)
    }

    private func fetchSingleWeather(for location: SavedLocation) async -> (Double, String)? {
        do {
            let weather: Weather
            if location.isCurrentLocation {
                weather = try await weatherRepository.fetchCurrentWeather()
            } else if let lat = location.latitude, let lon = location.longitude {
                let clLoc = CLLocation(latitude: lat, longitude: lon)
                weather = try await weatherRepository.fetchWeather(
                    for: clLoc,
                    cityName: location.cityName,
                    locationSubtitle: location.regionName
                )
            } else {
                return nil
            }
            return (weather.temperature, weather.weatherSymbolName)
        } catch {
            return nil
        }
    }
}

// MARK: - LocationRowView

private struct LocationRowView: View {
    let location: SavedLocation
    let isSelected: Bool
    let weatherSummary: (temperature: Double, symbolName: String)?
    var onSelect: (() -> Void)?

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.weatherFormatter) private var weatherFormatter

    var body: some View {
        Button(action: { onSelect?() }) {
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            if location.isCurrentLocation {
                                Image(systemName: "location.fill")
                                    .font(AppFont.subheadlineSemibold)
                                    .foregroundStyle(AppTheme.accent)
                            }
                            Text(location.cityName)
                                .font(AppFont.headline)
                                .foregroundStyle(AppTheme.textPrimary)
                            Spacer()
                            if isSelected {
                                Image(systemName: "checkmark")
                                    .font(AppFont.bodySemibold)
                                    .foregroundStyle(AppTheme.accent)
                            }
                        }

                        Text(subtitleText)
                            .font(AppFont.footnote)
                            .foregroundStyle(AppTheme.textSecondary)

                        if let summary = weatherSummary {
                            HStack(spacing: 8) {
                                Text(weatherFormatter.temp(summary.temperature))
                                    .font(AppFont.headline)
                                    .foregroundStyle(AppTheme.textPrimary)

                                Image(systemName: summary.symbolName)
                                    .symbolRenderingMode(.multicolor)
                                    .symbolVariant(.fill)
                                    .foregroundStyle(AppTheme.textPrimary)
                                    .font(AppFont.title2)
                            }
                        }
                    }
                } else {
                    HStack(spacing: 12) {
                        // Left indicator: location arrow for GPS
                        if location.isCurrentLocation {
                            Image(systemName: "location.fill")
                                .font(AppFont.subheadlineSemibold)
                                .foregroundStyle(AppTheme.accent)
                                .frame(width: 18)
                        }

                        // City & Region
                        VStack(alignment: .leading, spacing: 3) {
                            Text(location.cityName)
                                .font(AppFont.headline)
                                .foregroundStyle(AppTheme.textPrimary)
                                .lineLimit(1)
                            Text(subtitleText)
                                .font(AppFont.footnote)
                                .foregroundStyle(AppTheme.textSecondary)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        // Current temperature and weather symbol
                        if let summary = weatherSummary {
                            HStack(spacing: 8) {
                                Text(weatherFormatter.temp(summary.temperature))
                                    .font(AppFont.headline)
                                    .foregroundStyle(AppTheme.textPrimary)

                                Image(systemName: summary.symbolName)
                                    .symbolRenderingMode(.multicolor)
                                    .symbolVariant(.fill)
                                    .foregroundStyle(AppTheme.textPrimary)
                                    .font(AppFont.title2)
                                    .frame(width: 26, height: 26)
                            }
                        }

                        // Selected city checkmark
                        if isSelected {
                            Image(systemName: "checkmark")
                                .font(AppFont.bodySemibold)
                                .foregroundStyle(AppTheme.accent)
                                .frame(width: 20)
                        }
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? Color.white.opacity(0.12) : Color.clear)
            )
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

#Preview("Locations") {
    LocationsView()
}

#Preview("Locations AX3") {
    LocationsView()
        .dynamicTypeSize(.accessibility3)
}
