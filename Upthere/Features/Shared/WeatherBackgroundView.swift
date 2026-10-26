import SwiftUI

// MARK: - WeatherBackgroundView (Compatibility Adapter)

struct WeatherBackgroundView: View {
    let scene: SkyScene
    let isPaused: Bool

    init(scene: SkyScene, isPaused: Bool = false) {
        self.scene = scene
        self.isPaused = isPaused
    }

    init(condition: String?, symbolName: String? = nil, isDaylight: Bool? = nil, isPaused: Bool = false) {
        self.scene = SkyScene.from(condition: condition, symbolName: symbolName, isDaylight: isDaylight)
        self.isPaused = isPaused
    }

    var body: some View {
        SkyBackgroundView(scene: scene, isPaused: isPaused)
    }
}
