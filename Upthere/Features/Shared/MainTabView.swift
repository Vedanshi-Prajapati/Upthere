import SwiftUI

public struct MainTabView: View {
    @State private var selectedTab: AppTab = .home
    @State private var showPermission = LocationService.shared.authorizationStatus == .notDetermined

    private let homeViewModel: HomeViewModel
    private let settingsViewModel: SettingsViewModel

    public init(homeViewModel: HomeViewModel, settingsViewModel: SettingsViewModel? = nil) {
        self.homeViewModel = homeViewModel
        self.settingsViewModel = settingsViewModel ?? SettingsViewModel()
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

            SettingsView(viewModel: settingsViewModel)
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
                    LocationService.shared.requestAuthorization()
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
