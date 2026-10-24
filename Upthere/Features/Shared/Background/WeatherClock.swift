import SwiftUI

public struct WeatherClockKey: EnvironmentKey {
    public static let defaultValue: TimeInterval = 0.0
}

public struct WeatherParticleScaleKey: EnvironmentKey {
    public static let defaultValue: Double = 1.0
}

public struct IsWeatherAnimationPausedKey: EnvironmentKey {
    public static let defaultValue: Bool = false
}

public struct IsHomeTabSelectedKey: EnvironmentKey {
    public static let defaultValue: Bool = true
}

extension EnvironmentValues {
    public var weatherClockTime: TimeInterval {
        get { self[WeatherClockKey.self] }
        set { self[WeatherClockKey.self] = newValue }
    }

    public var weatherParticleScale: Double {
        get { self[WeatherParticleScaleKey.self] }
        set { self[WeatherParticleScaleKey.self] = newValue }
    }

    public var isWeatherAnimationPaused: Bool {
        get { self[IsWeatherAnimationPausedKey.self] }
        set { self[IsWeatherAnimationPausedKey.self] = newValue }
    }

    public var isHomeTabSelected: Bool {
        get { self[IsHomeTabSelectedKey.self] }
        set { self[IsHomeTabSelectedKey.self] = newValue }
    }
}
