import SwiftUI

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
                    settingsViewModel: container.settingsViewModel
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
        }
    }
}
