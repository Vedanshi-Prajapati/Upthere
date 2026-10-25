import SwiftUI

struct WeatherClockKey: EnvironmentKey {
    static let defaultValue: TimeInterval = 0.0
}

struct WeatherParticleScaleKey: EnvironmentKey {
    static let defaultValue: Double = 1.0
}

struct IsWeatherAnimationPausedKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

struct IsHomeTabSelectedKey: EnvironmentKey {
    static let defaultValue: Bool = true
}

extension EnvironmentValues {
    var weatherClockTime: TimeInterval {
        get { self[WeatherClockKey.self] }
        set { self[WeatherClockKey.self] = newValue }
    }

    var weatherParticleScale: Double {
        get { self[WeatherParticleScaleKey.self] }
        set { self[WeatherParticleScaleKey.self] = newValue }
    }

    var isWeatherAnimationPaused: Bool {
        get { self[IsWeatherAnimationPausedKey.self] }
        set { self[IsWeatherAnimationPausedKey.self] = newValue }
    }

    var isHomeTabSelected: Bool {
        get { self[IsHomeTabSelectedKey.self] }
        set { self[IsHomeTabSelectedKey.self] = newValue }
    }
}
