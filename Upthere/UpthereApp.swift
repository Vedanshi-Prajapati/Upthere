import SwiftUI
import CoreSpotlight

@main
struct UpthereApp: App {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var container = AppContainer()
    @State private var showSplash = true

    init() {
        AppGroup.migrateSettingsIfNeeded()
    }

    private var isTesting: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    private var initialTab: AppTab {
        #if DEBUG
        if let idx = ProcessInfo.processInfo.arguments.firstIndex(of: "-initialTab"),
           idx + 1 < ProcessInfo.processInfo.arguments.count,
           let tab = AppTab(rawValue: ProcessInfo.processInfo.arguments[idx + 1].lowercased()) {
            return tab
        }
        #endif
        return .home
    }

    private var disableSplash: Bool {
        if isTesting { return true }
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-disableSplash") || ProcessInfo.processInfo.arguments.contains("-useMockRepository") {
            return true
        }
        #endif
        return false
    }

    private var showPermission: Bool? {
        if isTesting { return false }
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-disablePermission") || ProcessInfo.processInfo.arguments.contains("-useMockRepository") {
            return false
        }
        #endif
        return nil
    }

    private var isInitialStateReady: Bool {
        switch container.homeViewModel.state {
        case .loaded, .error:
            return true
        case .idle, .loading:
            return false
        }
    }

    var body: some Scene {
        WindowGroup {
            if isTesting {
                Color.clear
            } else {
                ZStack {
                    MainTabView(
                        homeViewModel: container.homeViewModel,
                        settingsViewModel: container.settingsViewModel,
                        locationService: container.locationService,
                        locationsManager: container.locationsManager,
                        initialTab: initialTab,
                        showPermission: showPermission
                    )
                        .opacity((showSplash && !disableSplash) ? 0 : 1)

                    if showSplash && !disableSplash {
                        SplashView()
                            .transition(.opacity)
                    }
                }
                .environment(\.weatherFormatter, container.weatherFormatter)
                .environment(container.unitPreferences)
                .preferredColorScheme(.dark)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.5), value: showSplash)
                .task {
                    guard showSplash && !disableSplash else { return }
                    if reduceMotion {
                        showSplash = false
                        return
                    }
                    let deadline = ContinuousClock.now + .milliseconds(600)
                    while showSplash && ContinuousClock.now < deadline {
                        if isInitialStateReady {
                            break
                        }
                        // Genuinely optional: cooperative polling sleep while waiting for initial state
                        try? await Task.sleep(for: .milliseconds(20))
                    }
                    showSplash = false
                }
                .onContinueUserActivity(CSSearchableItemActionType) { userActivity in
                    guard let identifier = userActivity.userInfo?[CSSearchableItemActivityIdentifier] as? String,
                          let cityName = SpotlightService.shared.resolveCityName(from: identifier) else {
                        return
                    }
                    if let matched = container.locationsManager.savedLocations.first(where: {
                        $0.cityName.caseInsensitiveCompare(cityName) == .orderedSame
                    }) {
                        container.homeViewModel.selectLocation(matched)
                    } else {
                        let newLoc = SavedLocation(cityName: cityName, regionName: "", condition: "--")
                        container.homeViewModel.selectLocation(newLoc)
                    }
                }
            }
        }
    }
}
