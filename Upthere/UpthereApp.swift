import SwiftUI

@main
struct UpthereApp: App {
    @State private var container = AppContainer()
    @State private var showSplash = true

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
