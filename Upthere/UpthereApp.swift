import SwiftUI

@main
struct UpthereApp: App {
    @State private var container = AppContainer()

    var body: some Scene {
        WindowGroup {
            MainTabView(homeViewModel: container.makeHomeViewModel())
        }
    }
}
