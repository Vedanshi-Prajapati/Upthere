import SwiftUI
import Combine

@MainActor
@Observable
public final class WeatherAnimationManager {
    public static let shared = WeatherAnimationManager()

    public private(set) var isLowPowerModeEnabled: Bool
    public private(set) var thermalState: ProcessInfo.ThermalState

    private var cancellables = Set<AnyCancellable>()

    public init() {
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

    public func shouldPause(
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

    public var particleScale: Double {
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
