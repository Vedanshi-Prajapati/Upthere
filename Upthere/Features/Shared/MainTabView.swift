import SwiftUI

public struct MainTabView: View {
    @State private var selectedTab: Tab = .home
    @State private var showLocations = false
    @State private var showPermission = true

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
                case .home:     HomeView(viewModel: homeViewModel)
                case .forecast: ForecastView()
                case .insights: InsightsView()
                case .locations:
                    LocationsView(onDone: { selectedTab = .home })
                case .settings: SettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea()

            // Custom Tab Bar
            CustomTabBar(selected: $selectedTab)
        }
        .ignoresSafeArea(edges: .bottom)
        .sheet(isPresented: $showPermission) {
            LocationPermissionView(
                onAllow: { showPermission = false },
                onSearchInstead: { showPermission = false }
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
        case .home:      return "house.fill"
        case .forecast:  return "calendar"
        case .insights:  return "sparkles"
        case .locations: return "location.fill"
        case .settings:  return "gearshape"
        }
    }
}

// MARK: - CustomTabBar

private struct CustomTabBar: View {
    @Binding var selected: Tab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selected = tab
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 20, weight: selected == tab ? .semibold : .regular))
                            .foregroundStyle(selected == tab ? .white : .white.opacity(0.55))
                        Text(tab.title)
                            .font(.system(size: 10, weight: selected == tab ? .semibold : .regular))
                            .foregroundStyle(selected == tab ? .white : .white.opacity(0.55))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        Group {
                            if selected == tab {
                                Capsule()
                                    .fill(Color.white.opacity(0.14))
                                    .padding(.horizontal, 4)
                            }
                        }
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, 24)
        .background(
            Rectangle()
                .fill(AppTheme.tabBarBackground.opacity(0.92))
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(Color.white.opacity(0.12))
                        .frame(height: 1)
                }
        )
        .compositingGroup()
    }
}

#Preview {
    let repo = MockWeatherRepository()
    let uc = GetWeatherUseCase(repository: repo)
    let vm = HomeViewModel(getWeatherUseCase: uc)
    return MainTabView(homeViewModel: vm)
}
