import SwiftUI
import Combine

@MainActor
@Observable
final class WeatherAnimationManager {
    static let shared = WeatherAnimationManager()

    private(set) var isLowPowerModeEnabled: Bool
    private(set) var thermalState: ProcessInfo.ThermalState

    private var cancellables = Set<AnyCancellable>()

    init() {
        self.isLowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled
        self.thermalState = ProcessInfo.processInfo.thermalState

        NotificationCenter.default.publisher(for: Notification.Name.NSProcessInfoPowerStateDidChange)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.isLowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: ProcessInfo.thermalStateDidChangeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.thermalState = ProcessInfo.processInfo.thermalState
            }
            .store(in: &cancellables)
    }

    func shouldPause(
        scenePhase: ScenePhase,
        isHomeTab: Bool,
        reduceMotion: Bool
    ) -> Bool {
        if scenePhase != .active { return true }
        if !isHomeTab { return true }
        if isLowPowerModeEnabled { return true }
        if thermalState == .serious || thermalState == .critical { return true }
        if reduceMotion { return true }
        return false
    }

    var particleScale: Double {
        switch thermalState {
        case .serious:
            return 0.5
        case .critical:
            return 0.0
        default:
            return 1.0
        }
    }
}
