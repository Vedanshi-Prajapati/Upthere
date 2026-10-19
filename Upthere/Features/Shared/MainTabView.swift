import SwiftUI
import CoreLocation

public struct MainTabView: View {
    @State private var selectedTab: AppTab
    @State private var showPermission: Bool

    private let homeViewModel: HomeViewModel
    private let settingsViewModel: SettingsViewModel
    private let locationService: LocationService
    private let locationsManager: SavedLocationsManager

    public init(
        homeViewModel: HomeViewModel,
        settingsViewModel: SettingsViewModel? = nil,
        locationService: LocationService? = nil,
        locationsManager: SavedLocationsManager? = nil,
        initialTab: AppTab = .home,
        showPermission: Bool? = nil
    ) {
        self.homeViewModel = homeViewModel
        let loc = locationService ?? homeViewModel.locationService
        self.locationService = loc
        self.settingsViewModel = settingsViewModel ?? SettingsViewModel(locationService: loc)
        self.locationsManager = locationsManager ?? homeViewModel.locationsManager
        self._showPermission = State(initialValue: showPermission ?? (loc.authorizationStatus == .notDetermined))
        self._selectedTab = State(initialValue: initialTab)
    }

    public var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Home", systemImage: "house", value: .home) {
                HomeView(viewModel: homeViewModel, onNavigateToInsights: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        selectedTab = .insights
                    }
                })
                .dynamicTypeSize(.xSmall ... .accessibility5)
            }

            Tab("Forecast", systemImage: "calendar", value: .forecast) {
                ForecastView(viewModel: homeViewModel)
                    .dynamicTypeSize(.xSmall ... .accessibility5)
            }

            Tab("Insights", systemImage: "sparkles", value: .insights) {
                InsightsView(viewModel: homeViewModel)
                    .dynamicTypeSize(.xSmall ... .accessibility5)
            }

            Tab("Locations", systemImage: "mappin.and.ellipse", value: .locations) {
                LocationsView(
                    condition: homeViewModel.displayedWeather?.condition,
                    symbolName: homeViewModel.displayedWeather?.weatherSymbolName,
                    locationsManager: locationsManager,
                    locationService: locationService,
                    onSelectLocation: { location in
                        homeViewModel.selectLocation(location)
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            selectedTab = .home
                        }
                    }
                )
                .dynamicTypeSize(.xSmall ... .accessibility5)
            }

            Tab("Settings", systemImage: "gearshape", value: .settings) {
                SettingsView(
                    viewModel: settingsViewModel,
                    locationService: locationService,
                    condition: homeViewModel.displayedWeather?.condition,
                    symbolName: homeViewModel.displayedWeather?.weatherSymbolName
                )
                .dynamicTypeSize(.xSmall ... .accessibility5)
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
        .task {
            if homeViewModel.displayedWeather == nil {
                await homeViewModel.loadWeather()
            }
        }
        .fullScreenCover(isPresented: $showPermission) {
            LocationPermissionView(
                onAllow: {
                    showPermission = false
                    locationService.requestAuthorization()
                    Task {
                        try? await Task.sleep(nanoseconds: 600_000_000)
                        await homeViewModel.loadWeather(force: true)
                    }
                },
                onSearchInstead: {
                    showPermission = false
                }
            )
        }
    }
}

// MARK: - Tab enum

public enum AppTab: String, CaseIterable, Hashable, Sendable {
    case home, forecast, insights, locations, settings
}

#Preview {
    let repo = MockWeatherRepository()
    let uc = GetWeatherUseCase(repository: repo)
    let vm = HomeViewModel(getWeatherUseCase: uc)
    return MainTabView(homeViewModel: vm)
}
