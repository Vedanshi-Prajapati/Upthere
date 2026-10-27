import SwiftUI
import CoreLocation

struct MainTabView: View {
    @State private var selectedTab: AppTab
    @State private var showPermission: Bool

    private let homeViewModel: HomeViewModel
    private let settingsViewModel: SettingsViewModel
    private let locationService: LocationService
    private let locationsManager: SavedLocationsManager

    init(
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
        let isTesting = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        let initialPermission = isTesting ? false : (showPermission ?? (loc.authorizationStatus == .notDetermined))
        self._showPermission = State(initialValue: initialPermission)
        self._selectedTab = State(initialValue: initialTab)
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    private var isLowPowerMode: Bool {
        WeatherAnimationManager.shared.isLowPowerModeEnabled
    }

    private var shouldPauseAnimation: Bool {
        if reduceMotion { return true }
        if isLowPowerMode { return true }
        if scenePhase != .active { return true }
        if selectedTab != .home { return true }
        return false
    }

    private var currentSkyScene: SkyScene {
        #if DEBUG
        if let override = SkyScene.debugOverride {
            return override
        }
        #endif
        return SkyScene.from(
            condition: homeViewModel.displayedWeather?.condition,
            isDaylight: homeViewModel.displayedWeather?.isDaylight ?? true
        )
    }

    var body: some View {
        ZStack {
            // PHASE 2: Sky lives in a ZStack behind the TabView so it shows through
            // every tab. Placing it in .background{} caused the system TabView
            // content layer to paint over it with an opaque material.
            SkyBackgroundView(
                scene: currentSkyScene,
                isPaused: shouldPauseAnimation
            )
            .ignoresSafeArea()
            .accessibilityIdentifier("sky-background")
            .accessibilityHidden(true)

            TabView(selection: $selectedTab) {
                Tab("Home", systemImage: "house", value: .home) {
                    HomeView(viewModel: homeViewModel, onNavigateToInsights: {
                        withAnimation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.75)) {
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
                            withAnimation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.75)) {
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
            // Make TabView background transparent so the sky ZStack layer shows through
            .toolbarBackground(.clear, for: .tabBar)
        }
        .environment(\.isHomeTabSelected, selectedTab == .home)
        .tabBarMinimizeBehavior(.onScrollDown)
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
        .task {
            let isTesting = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
            if !isTesting && homeViewModel.displayedWeather == nil {
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

enum AppTab: String, CaseIterable, Hashable, Sendable {
    case home, forecast, insights, locations, settings
}

#if DEBUG
#Preview {
    let repo = MockWeatherRepository()
    let uc = GetWeatherUseCase(repository: repo)
    let vm = HomeViewModel(getWeatherUseCase: uc)
    return MainTabView(homeViewModel: vm)
}
#endif
