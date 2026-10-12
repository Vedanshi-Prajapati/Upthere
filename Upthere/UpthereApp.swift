import SwiftUI

@main
struct UpthereApp: App {
    @State private var container = AppContainer()
    @State private var showSplash = true

    @AppStorage("settings.appearanceMode") private var appearanceModeRaw: String = AppearanceMode.system.rawValue
    @AppStorage("settings.textSize") private var textSizeRaw: String = TextSize.default_.rawValue

    private var selectedColorScheme: ColorScheme? {
        AppearanceMode(rawValue: appearanceModeRaw)?.colorScheme
    }

    private var selectedDynamicTypeSize: DynamicTypeSize {
        (TextSize(rawValue: textSizeRaw) ?? .default_).dynamicTypeSize
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                MainTabView(homeViewModel: container.makeHomeViewModel())
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
            .task {
                if ProcessInfo.processInfo.arguments.contains("--run-tests") {
                    let results = await EdgeCaseTests.runAllTests()
                    print("\n================== EDGE CASE AUDIT TEST RESULTS ==================")
                    var passedCount = 0
                    for res in results {
                        let status = res.passed ? "PASSED" : "FAILED"
                        if res.passed { passedCount += 1 }
                        print("[\(String(format: "%02d", res.id))/24] [\(status)] - \(res.name): \(res.message)")
                    }
                    print("==================================================================")
                    print("SUMMARY: \(passedCount)/\(results.count) TESTS PASSED")
                    print("==================================================================\n")
                }
            }
        }
    }
}
