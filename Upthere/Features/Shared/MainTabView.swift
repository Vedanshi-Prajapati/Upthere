import SwiftUI

public struct MainTabView: View {
    @State private var selectedTab: Tab = .home
    @State private var showLocations = false
    @State private var showPermission = LocationService.shared.authorizationStatus == .notDetermined

    private let homeViewModel: HomeViewModel

    public init(homeViewModel: HomeViewModel) {
        self.homeViewModel = homeViewModel
        // Suppress default tab bar appearance
        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    public var body: some View {
        ZStack(alignment: .bottom) {
            // Page content
            ZStack {
                switch selectedTab {
                case .home:
                    HomeView(viewModel: homeViewModel, onNavigateToInsights: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            selectedTab = .insights
                        }
                    })
                case .forecast: ForecastView(viewModel: homeViewModel)
                case .insights: InsightsView(viewModel: homeViewModel)
                case .locations:
                    LocationsView(
                        onSelectLocation: { location in
                            homeViewModel.selectLocation(location)
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                selectedTab = .home
                            }
                        },
                        onDone: { selectedTab = .home }
                    )
                case .settings: SettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea()

            // Custom Tab Bar
            CustomTabBar(selected: $selectedTab)
                .padding(.horizontal, 20)
                .padding(.bottom, 36)
        }
        .ignoresSafeArea()
        .sheet(isPresented: $showPermission) {
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
            .presentationDetents([.large])
            .presentationDragIndicator(.hidden)
        }
    }
}

// MARK: - Tab enum

public enum Tab: CaseIterable {
    case home, forecast, insights, locations, settings

    var title: String {
        switch self {
        case .home:      return "Home"
        case .forecast:  return "Forecast"
        case .insights:  return "Insights"
        case .locations: return "Locations"
        case .settings:  return "Settings"
        }
    }

    var icon: String {
        switch self {
        case .home:      return "house"
        case .forecast:  return "calendar"
        case .insights:  return "sparkles"
        case .locations: return "mappin.and.ellipse"
        case .settings:  return "scope"
        }
    }
}

// MARK: - CustomTabBar

private struct CustomTabBar: View {
    @Binding var selected: Tab
    @Namespace private var tabAnimation

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.72)) {
                        selected = tab
                    }
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 20, weight: selected == tab ? .semibold : .regular))
                            .foregroundStyle(selected == tab ? .white : Color.white.opacity(0.65))

                        Text(tab.title)
                            .font(.system(size: 10, weight: selected == tab ? .semibold : .medium))
                            .foregroundStyle(selected == tab ? .white : Color.white.opacity(0.65))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background {
                        if selected == tab {
                            Capsule()
                                .fill(Color.white.opacity(0.25))
                                .matchedGeometryEffect(id: "selectedTabIndicator", in: tabAnimation)
                                .padding(.horizontal, 3)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 5)
        .frame(height: 64)
        .background {
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule()
                        .fill(Color(red: 18/255, green: 42/255, blue: 82/255).opacity(0.75))
                )
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.20), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.25), radius: 18, x: 0, y: 8)
        }
    }
}

#Preview {
    let repo = MockWeatherRepository()
    let uc = GetWeatherUseCase(repository: repo)
    let vm = HomeViewModel(getWeatherUseCase: uc)
    return MainTabView(homeViewModel: vm)
}
