import SwiftUI

// MARK: - Weather Illustration Type

enum WeatherIllustrationType: String, Equatable, Sendable {
    case clearDay
    case clearNight
    case partlyCloudyDay
    case partlyCloudyNight
    case cloudy
    case rainy
    case heavyRain
    case thunderstorm
    case snowy
    case windy
    case foggy

    static func from(condition: String?, symbolName: String? = nil) -> WeatherIllustrationType {
        let cond = (condition ?? "").lowercased()
        let sym = (symbolName ?? "").lowercased()

        let isNight = sym.contains("moon") || cond.contains("night")

        if cond.contains("thunder") || cond.contains("storm") || cond.contains("lightning") || sym.contains("bolt") {
            return .thunderstorm
        }
        if cond.contains("snow") || cond.contains("blizzard") || cond.contains("sleet") || cond.contains("flurr") || cond.contains("hail") || sym.contains("snow") {
            return .snowy
        }
        if cond.contains("heavy rain") || sym.contains("heavyrain") {
            return .heavyRain
        }
        if cond.contains("rain") || cond.contains("drizzle") || cond.contains("shower") || sym.contains("rain") || sym.contains("drizzle") {
            return .rainy
        }
        if cond.contains("wind") || cond.contains("breeze") || cond.contains("gale") || sym.contains("wind") {
            return .windy
        }
        if cond.contains("fog") || cond.contains("mist") || cond.contains("haze") || cond.contains("smoke") || sym.contains("fog") {
            return .foggy
        }
        if isNight {
            if cond.contains("cloud") || sym.contains("cloud") {
                return .partlyCloudyNight
            }
            return .clearNight
        }
        if cond.contains("partly cloudy") || (sym.contains("cloud") && (sym.contains("sun") || cond.contains("sun"))) {
            return .partlyCloudyDay
        }
        if cond.contains("cloud") || cond.contains("overcast") || sym.contains("cloud") {
            return .cloudy
        }
        if cond.contains("sun") || cond.contains("clear") || sym.contains("sun") {
            return .clearDay
        }
        return .partlyCloudyDay
    }
}

// MARK: - Master WeatherIllustrationView

struct WeatherIllustrationView: View {
    let type: WeatherIllustrationType
    let size: CGFloat
    let animated: Bool

    init(
        type: WeatherIllustrationType,
        size: CGFloat = 80,
        animated: Bool = true
    ) {
        self.type = type
        self.size = size
        self.animated = animated
    }

    init(
        condition: String?,
        symbolName: String? = nil,
        size: CGFloat = 80,
        animated: Bool = true
    ) {
        self.type = WeatherIllustrationType.from(condition: condition, symbolName: symbolName)
        self.size = size
        self.animated = animated
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.weatherClockTime) private var clockTime
    @Environment(\.isWeatherAnimationPaused) private var isPaused

    var body: some View {
        let t = (animated && !reduceMotion && !isPaused) ? clockTime : 0.0
        illustrationContent(time: t)
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private func illustrationContent(time: TimeInterval) -> some View {
        switch type {
        case .clearDay:
            ClearDayIllustration(size: size, time: time, animated: animated)
        case .clearNight:
            ClearNightIllustration(size: size, time: time, animated: animated)
        case .partlyCloudyDay:
            PartlyCloudyDayIllustration(size: size, time: time, animated: animated)
        case .partlyCloudyNight:
            PartlyCloudyNightIllustration(size: size, time: time, animated: animated)
        case .cloudy:
            CloudyIllustration(size: size, time: time, animated: animated)
        case .rainy:
            RainyIllustration(isHeavy: false, size: size, time: time, animated: animated)
        case .heavyRain:
            RainyIllustration(isHeavy: true, size: size, time: time, animated: animated)
        case .thunderstorm:
            ThunderstormIllustration(size: size, time: time, animated: animated)
        case .snowy:
            SnowyIllustration(size: size, time: time, animated: animated)
        case .windy:
            WindyIllustration(size: size, time: time, animated: animated)
        case .foggy:
            FoggyIllustration(size: size, time: time, animated: animated)
        }
    }

    private var accessibilityLabelText: String {
        switch type {
        case .clearDay: return "Sunny"
        case .clearNight: return "Clear Night"
        case .partlyCloudyDay: return "Partly Cloudy"
        case .partlyCloudyNight: return "Partly Cloudy Night"
        case .cloudy: return "Cloudy"
        case .rainy: return "Rainy"
        case .heavyRain: return "Heavy Rain"
        case .thunderstorm: return "Thunderstorm"
        case .snowy: return "Snowy"
        case .windy: return "Windy"
        case .foggy: return "Foggy"
        }
    }
}
