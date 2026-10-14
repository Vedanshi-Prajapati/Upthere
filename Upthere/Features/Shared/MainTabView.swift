import SwiftUI

public struct MainTabView: View {
    @State private var selectedTab: AppTab = .home
    @State private var showPermission: Bool

    private let homeViewModel: HomeViewModel
    private let settingsViewModel: SettingsViewModel
    private let locationService: LocationService

    public init(
        homeViewModel: HomeViewModel,
        settingsViewModel: SettingsViewModel? = nil,
        locationService: LocationService? = nil
    ) {
        self.homeViewModel = homeViewModel
        let loc = locationService ?? homeViewModel.locationService
        self.locationService = loc
        self.settingsViewModel = settingsViewModel ?? SettingsViewModel(locationService: loc)
        self._showPermission = State(initialValue: loc.authorizationStatus == .notDetermined)
    }

    public var body: some View {
        TabView(selection: $selectedTab) {
            HomeView(viewModel: homeViewModel, onNavigateToInsights: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                    selectedTab = .insights
                }
            })
            .tabItem {
                Label("Home", systemImage: "house")
            }
            .tag(AppTab.home)

            ForecastView(viewModel: homeViewModel)
                .tabItem {
                    Label("Forecast", systemImage: "calendar")
                }
                .tag(AppTab.forecast)

            InsightsView(viewModel: homeViewModel)
                .tabItem {
                    Label("Insights", systemImage: "sparkles")
                }
                .tag(AppTab.insights)

            LocationsView(
                condition: homeViewModel.displayedWeather?.condition,
                symbolName: homeViewModel.displayedWeather?.weatherSymbolName,
                locationService: locationService,
                onSelectLocation: { location in
                    homeViewModel.selectLocation(location)
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        selectedTab = .home
                    }
                }
            )
            .tabItem {
                Label("Locations", systemImage: "mappin.and.ellipse")
            }
            .tag(AppTab.locations)

            SettingsView(
                viewModel: settingsViewModel,
                condition: homeViewModel.displayedWeather?.condition,
                symbolName: homeViewModel.displayedWeather?.weatherSymbolName
            )
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(AppTab.settings)
        }
        .ignoresSafeArea()
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

public enum AppTab: String, CaseIterable {
    case home, forecast, insights, locations, settings
}

#Preview {
    let repo = MockWeatherRepository()
    let uc = GetWeatherUseCase(repository: repo)
    let vm = HomeViewModel(getWeatherUseCase: uc)
    return MainTabView(homeViewModel: vm)
}
