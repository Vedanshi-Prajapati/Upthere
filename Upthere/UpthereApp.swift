import SwiftUI
import CoreSpotlight

@main
struct UpthereApp: App {
    @State private var container = AppContainer()
    @State private var showSplash = true

    private var selectedColorScheme: ColorScheme? {
        container.settingsViewModel.appearanceMode.colorScheme
    }

    private var initialTab: AppTab {
        if let idx = ProcessInfo.processInfo.arguments.firstIndex(of: "-initialTab"),
           idx + 1 < ProcessInfo.processInfo.arguments.count,
           let tab = AppTab(rawValue: ProcessInfo.processInfo.arguments[idx + 1].lowercased()) {
            return tab
        }
        return .home
    }

    private var disableSplash: Bool {
        ProcessInfo.processInfo.arguments.contains("-disableSplash")
    }

    private var showPermission: Bool? {
        ProcessInfo.processInfo.arguments.contains("-disablePermission") ? false : nil
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                MainTabView(
                    homeViewModel: container.homeViewModel,
                    settingsViewModel: container.settingsViewModel,
                    initialTab: initialTab,
                    showPermission: showPermission
                )
                    .opacity((showSplash && !disableSplash) ? 0 : 1)

                if showSplash && !disableSplash {
                    SplashView()
                        .transition(.opacity)
                }
            }
            .preferredColorScheme(selectedColorScheme)
            .animation(.easeInOut(duration: 0.5), value: showSplash)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                    showSplash = false
                }
            }
            .onContinueUserActivity(CSSearchableItemActionType) { userActivity in
                guard let identifier = userActivity.userInfo?[CSSearchableItemActivityIdentifier] as? String,
                      let cityName = SpotlightService.shared.resolveCityName(from: identifier) else {
                    return
                }
                if let matched = SavedLocationsManager.shared.savedLocations.first(where: {
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
