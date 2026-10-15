import SwiftUI
import CoreSpotlight

@main
struct UpthereApp: App {
    @State private var container = AppContainer()
    @State private var showSplash = true

    private var selectedColorScheme: ColorScheme? {
        container.settingsViewModel.appearanceMode.colorScheme
    }

    private var selectedDynamicTypeSize: DynamicTypeSize {
        container.settingsViewModel.textSize.dynamicTypeSize
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                MainTabView(
                    homeViewModel: container.homeViewModel,
                    settingsViewModel: container.settingsViewModel,
                    initialTab: .locations,
                    showPermission: false
                )
                    .opacity(showSplash ? 0 : 1)

                if showSplash {
                    SplashView()
                        .transition(.opacity)
                }
            }
            .preferredColorScheme(selectedColorScheme)
            .dynamicTypeSize(selectedDynamicTypeSize)
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
