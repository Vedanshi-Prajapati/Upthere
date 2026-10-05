import SwiftUI

@main
struct UpthereApp: App {
    @State private var container = AppContainer()

    var body: some Scene {
        WindowGroup {
            HomeView(viewModel: container.makeHomeViewModel())
        }
    }
}
