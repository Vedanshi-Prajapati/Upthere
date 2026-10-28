import Foundation
import CoreLocation
import WeatherKit
import WidgetKit
import os

// MARK: - Domain Models

public struct RainWindow: Equatable, Sendable, Codable {
    public let title: String
    public let timeRange: String
    public let detail: String

    public init(title: String, timeRange: String, detail: String) {
        self.title = title
        self.timeRange = timeRange
        self.detail = detail
    }
}

public struct WeatherAlert: Equatable, Sendable, Codable, Identifiable {
    public let id: String
    public let source: String
    public let title: String
    public let validUntil: String
    public let details: String?
    public let severity: String?
    public let expirationDate: Date?

    public init(
        id: String? = nil,
        source: String,
        title: String,
        validUntil: String,
        details: String? = nil,
        severity: String? = nil,
        expirationDate: Date? = nil
    ) {
        self.id = id ?? "\(source)_\(title)_\(validUntil)"
        self.source = source
        self.title = title
        self.validUntil = validUntil
        self.details = details
        self.severity = severity
        self.expirationDate = expirationDate
    }

    public var isExpired: Bool {
        if let expirationDate = expirationDate {
            return expirationDate < Date()
        }
        return false
    }

    enum CodingKeys: String, CodingKey {
        case id, source, title, validUntil, details, severity, expirationDate
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let source = try container.decode(String.self, forKey: .source)
        let title = try container.decode(String.self, forKey: .title)
        let validUntil = try container.decode(String.self, forKey: .validUntil)
        self.id = try container.decodeIfPresent(String.self, forKey: .id) ?? "\(source)_\(title)_\(validUntil)"
        self.source = source
        self.title = title
        self.validUntil = validUntil
        self.details = try container.decodeIfPresent(String.self, forKey: .details)
        self.severity = try container.decodeIfPresent(String.self, forKey: .severity)
        self.expirationDate = try container.decodeIfPresent(Date.self, forKey: .expirationDate)
    }
}

public struct DailyWeather: Equatable, Sendable, Identifiable, Codable {
    public let id: UUID
    public let dayName: String
    public let date: String
    public let symbolName: String
    public let precipitationProbability: Double
    public let lowTemperature: Double
    public let highTemperature: Double

    public init(
        id: UUID = UUID(),
        dayName: String,
        date: String,
        symbolName: String,
        precipitationProbability: Double = 0,
        lowTemperature: Double,
        highTemperature: Double
    ) {
        self.id = id
        self.dayName = dayName
        self.date = date
        self.symbolName = symbolName.isEmpty ? "cloud.sun.fill" : symbolName
        let p = precipitationProbability.isNaN || precipitationProbability.isInfinite ? 0.0 : precipitationProbability
        self.precipitationProbability = max(0.0, min(1.0, p))

        let rawLow = lowTemperature.isNaN || lowTemperature.isInfinite ? 20.0 : lowTemperature
        let rawHigh = highTemperature.isNaN || highTemperature.isInfinite ? 25.0 : highTemperature
        self.lowTemperature = min(rawLow, rawHigh)
        self.highTemperature = max(rawLow, rawHigh)
    }
}

public struct HourlyWeather: Equatable, Sendable, Identifiable, Codable {
    public let id: UUID
    public let date: Date
    public let temperature: Double
    public let feelsLike: Double
    public let precipitationChance: Double // 0.0 – 1.0
    public let precipitationAmount: Double // mm
    public let windSpeed: Double // km/h
    public let windGust: Double // km/h
    public let uvIndex: Int
    public let cloudCover: Double // 0.0 – 1.0
    public let symbolName: String
    public let isDaylight: Bool
    private let customTimeString: String?

    private enum CodingKeys: String, CodingKey {
        case id, date, temperature, feelsLike, precipitationChance, precipitationAmount
        case windSpeed, windGust, uvIndex, cloudCover, symbolName, isDaylight
    }

    public var precipitationProbability: Double { precipitationChance }
    public var wind: Double { windSpeed }
    public var gust: Double { windGust }
    public var symbol: String { symbolName }

    public var time: String {
        if let customTimeString {
            return customTimeString
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "ha"
        return formatter.string(from: date).lowercased().replacingOccurrences(of: "m", with: "")
    }

    public init(
        id: UUID = UUID(),
        date: Date = Date(),
        temperature: Double,
        feelsLike: Double? = nil,
        precipitationChance: Double,
        precipitationAmount: Double = 0.0,
        windSpeed: Double = 0.0,
        windGust: Double = 0.0,
        uvIndex: Int = 0,
        cloudCover: Double = 0.0,
        symbolName: String = "cloud.sun.fill",
        isDaylight: Bool = true
    ) {
        self.id = id
        self.date = date
        self.customTimeString = nil

        if temperature.isNaN || temperature.isInfinite {
            self.temperature = 20.0
        } else {
            self.temperature = temperature
        }

        let fl = feelsLike ?? self.temperature
        self.feelsLike = (fl.isNaN || fl.isInfinite) ? self.temperature : fl

        let p = precipitationChance.isNaN || precipitationChance.isInfinite ? 0.0 : precipitationChance
        self.precipitationChance = max(0.0, min(1.0, p))

        let pa = precipitationAmount.isNaN || precipitationAmount.isInfinite ? 0.0 : precipitationAmount
        self.precipitationAmount = max(0.0, pa)

        let w = windSpeed.isNaN || windSpeed.isInfinite ? 0.0 : windSpeed
        self.windSpeed = max(0.0, w)

        let g = windGust.isNaN || windGust.isInfinite ? self.windSpeed : windGust
        self.windGust = max(self.windSpeed, g)

        self.uvIndex = max(0, uvIndex)

        let c = cloudCover.isNaN || cloudCover.isInfinite ? 0.0 : cloudCover
        self.cloudCover = max(0.0, min(1.0, c))

        self.symbolName = symbolName.isEmpty ? "cloud.sun.fill" : symbolName
        self.isDaylight = isDaylight
    }

    public init(
        id: UUID = UUID(),
        time: String? = nil,
        date: Date = Date(),
        temperature: Double,
        feelsLike: Double? = nil,
        precipitationProbability: Double,
        precipitationAmount: Double = 0.0,
        windSpeed: Double = 0.0,
        windGust: Double = 0.0,
        uvIndex: Int = 0,
        cloudCover: Double = 0.0,
        symbolName: String = "cloud.sun.fill",
        isDaylight: Bool = true
    ) {
        self.id = id
        self.date = date
        self.customTimeString = time

        if temperature.isNaN || temperature.isInfinite {
            self.temperature = 20.0
        } else {
            self.temperature = temperature
        }

        let fl = feelsLike ?? self.temperature
        self.feelsLike = (fl.isNaN || fl.isInfinite) ? self.temperature : fl

        let p = precipitationProbability.isNaN || precipitationProbability.isInfinite ? 0.0 : precipitationProbability
        self.precipitationChance = max(0.0, min(1.0, p))

        let pa = precipitationAmount.isNaN || precipitationAmount.isInfinite ? 0.0 : precipitationAmount
        self.precipitationAmount = max(0.0, pa)

        let w = windSpeed.isNaN || windSpeed.isInfinite ? 0.0 : windSpeed
        self.windSpeed = max(0.0, w)

        let g = windGust.isNaN || windGust.isInfinite ? self.windSpeed : windGust
        self.windGust = max(self.windSpeed, g)

        self.uvIndex = max(0, uvIndex)

        let c = cloudCover.isNaN || cloudCover.isInfinite ? 0.0 : cloudCover
        self.cloudCover = max(0.0, min(1.0, c))

        self.symbolName = symbolName.isEmpty ? "cloud.sun.fill" : symbolName
        self.isDaylight = isDaylight
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.date = try container.decodeIfPresent(Date.self, forKey: .date) ?? Date()
        self.temperature = try container.decode(Double.self, forKey: .temperature)
        self.feelsLike = try container.decodeIfPresent(Double.self, forKey: .feelsLike) ?? self.temperature
        self.precipitationChance = try container.decode(Double.self, forKey: .precipitationChance)
        self.precipitationAmount = try container.decodeIfPresent(Double.self, forKey: .precipitationAmount) ?? 0.0
        self.windSpeed = try container.decodeIfPresent(Double.self, forKey: .windSpeed) ?? 0.0
        self.windGust = try container.decodeIfPresent(Double.self, forKey: .windGust) ?? self.windSpeed
        self.uvIndex = try container.decodeIfPresent(Int.self, forKey: .uvIndex) ?? 0
        self.cloudCover = try container.decodeIfPresent(Double.self, forKey: .cloudCover) ?? 0.0
        self.symbolName = try container.decodeIfPresent(String.self, forKey: .symbolName) ?? "cloud.sun.fill"
        self.isDaylight = try container.decodeIfPresent(Bool.self, forKey: .isDaylight) ?? true
        self.customTimeString = nil
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(date, forKey: .date)
        try container.encode(temperature, forKey: .temperature)
        try container.encode(feelsLike, forKey: .feelsLike)
        try container.encode(precipitationChance, forKey: .precipitationChance)
        try container.encode(precipitationAmount, forKey: .precipitationAmount)
        try container.encode(windSpeed, forKey: .windSpeed)
        try container.encode(windGust, forKey: .windGust)
        try container.encode(uvIndex, forKey: .uvIndex)
        try container.encode(cloudCover, forKey: .cloudCover)
        try container.encode(symbolName, forKey: .symbolName)
        try container.encode(isDaylight, forKey: .isDaylight)
    }
}

public enum LocationBannerAction: String, Equatable, Codable, Sendable {
    case openSettings
    case retry
}

public enum LocationStatus: String, Equatable, Codable, Sendable {
    case live
    case denied
    case restricted
    case servicesDisabled
    case timedOut
    case unavailable
    case savedCity

    public var bannerCopy: String? {
        switch self {
        case .live, .savedCity:
            return nil
        case .denied:
            return String(localized: "Location access is off. Using Ghaziabad. Open Settings")
        case .timedOut:
            return String(localized: "Couldn't get your location. Using Ghaziabad. Retry")
        case .servicesDisabled:
            return String(localized: "Location services are disabled. Using Ghaziabad. Open Settings")
        case .restricted:
            return String(localized: "Location access is restricted. Using Ghaziabad. Open Settings")
        case .unavailable:
            return String(localized: "Location is unavailable. Using Ghaziabad. Retry")
        }
    }

    public var bannerAction: LocationBannerAction? {
        switch self {
        case .live, .savedCity:
            return nil
        case .denied, .servicesDisabled, .restricted:
            return .openSettings
        case .timedOut, .unavailable:
            return .retry
        }
    }
}

public struct Weather: Equatable, Sendable, Codable {
    public let cityName: String
    public let locationSubtitle: String
    public let latitude: Double?
    public let longitude: Double?
    public let temperature: Double
    public let condition: String
    public let highTemperature: Double
    public let lowTemperature: Double
    public let feelsLike: Double
    public let weatherSymbolName: String
    public let description: String
    public let humidity: Int
    public let dewPoint: Double
    public let windSpeed: Double
    public let windDirection: String
    public let precipitationChance: Int
    public let uvIndex: Int
    public let uvDescription: String
    public let visibility: Double
    public let visibilityDescription: String
    public let pressure: Double
    public let pressureTrend: String
    public let alert: WeatherAlert?
    public let hourlyForecast: [HourlyWeather]
    public let dailyForecast: [DailyWeather]
    public let rainWindow: RainWindow?
    public let warmingInsight: String
    public let chanceOfRain: Int
    public let sunrise: String
    public let sunset: String
    public let fetchTimestamp: Date
    public let isCached: Bool
    public let locationStatus: LocationStatus

    enum CodingKeys: String, CodingKey {
        case cityName, locationSubtitle, latitude, longitude
        case temperature, condition, highTemperature, lowTemperature, feelsLike
        case weatherSymbolName, description, humidity, dewPoint, windSpeed, windDirection
        case precipitationChance, uvIndex, uvDescription, visibility, visibilityDescription
        case pressure, pressureTrend, alert, hourlyForecast, dailyForecast, rainWindow
        case warmingInsight, chanceOfRain, sunrise, sunset, fetchTimestamp, isCached
        case locationStatus
    }

    public init(
        cityName: String,
        locationSubtitle: String = "",
        latitude: Double? = nil,
        longitude: Double? = nil,
        temperature: Double,
        condition: String,
        highTemperature: Double,
        lowTemperature: Double,
        feelsLike: Double = 0,
        weatherSymbolName: String = "cloud.sun.fill",
        description: String = "",
        humidity: Int = 0,
        dewPoint: Double = 0,
        windSpeed: Double = 0,
        windDirection: String = "",
        precipitationChance: Int = 0,
        uvIndex: Int = 0,
        uvDescription: String = "",
        visibility: Double = 0,
        visibilityDescription: String = "",
        pressure: Double = 0,
        pressureTrend: String = "",
        alert: WeatherAlert? = nil,
        hourlyForecast: [HourlyWeather] = [],
        dailyForecast: [DailyWeather] = [],
        rainWindow: RainWindow? = nil,
        warmingInsight: String = "",
        chanceOfRain: Int = 0,
        sunrise: String = "",
        sunset: String = "",
        fetchTimestamp: Date = Date(),
        isCached: Bool = false,
        locationStatus: LocationStatus = .live
    ) {
        self.cityName = cityName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.locationSubtitle = locationSubtitle.trimmingCharacters(in: .whitespacesAndNewlines)
        self.latitude = latitude
        self.longitude = longitude

        let validTemp = (temperature.isNaN || temperature.isInfinite) ? 20.0 : temperature
        self.temperature = validTemp
        self.feelsLike = (feelsLike.isNaN || feelsLike.isInfinite) ? validTemp : feelsLike

        let rawLow = (lowTemperature.isNaN || lowTemperature.isInfinite) ? validTemp : lowTemperature
        let rawHigh = (highTemperature.isNaN || highTemperature.isInfinite) ? validTemp : highTemperature
        self.lowTemperature = min(rawLow, rawHigh)
        self.highTemperature = max(rawLow, rawHigh)

        self.condition = condition.isEmpty ? "Partly Cloudy" : condition
        self.weatherSymbolName = weatherSymbolName.isEmpty ? "cloud.sun.fill" : weatherSymbolName
        self.description = description

        self.humidity = max(0, min(100, humidity))
        self.dewPoint = (dewPoint.isNaN || dewPoint.isInfinite) ? validTemp : dewPoint
        self.windSpeed = max(0, (windSpeed.isNaN || windSpeed.isInfinite) ? 0 : windSpeed)
        self.windDirection = windDirection
        self.precipitationChance = max(0, min(100, precipitationChance))
        self.uvIndex = max(0, uvIndex)
        self.uvDescription = uvDescription
        self.visibility = max(0, (visibility.isNaN || visibility.isInfinite) ? 10 : visibility)
        self.visibilityDescription = visibilityDescription
        self.pressure = (pressure.isNaN || pressure.isInfinite || pressure <= 0) ? 1013.25 : pressure
        self.pressureTrend = pressureTrend

        if let alert = alert, !alert.isExpired {
            self.alert = alert
        } else {
            self.alert = nil
        }

        self.hourlyForecast = hourlyForecast
        self.dailyForecast = dailyForecast
        self.rainWindow = rainWindow
        self.warmingInsight = warmingInsight
        self.chanceOfRain = max(0, min(100, chanceOfRain))
        self.sunrise = sunrise
        self.sunset = sunset
        self.fetchTimestamp = fetchTimestamp
        self.isCached = isCached
        self.locationStatus = locationStatus
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.cityName = try container.decodeIfPresent(String.self, forKey: .cityName) ?? ""
        self.locationSubtitle = try container.decodeIfPresent(String.self, forKey: .locationSubtitle) ?? ""
        self.latitude = try container.decodeIfPresent(Double.self, forKey: .latitude)
        self.longitude = try container.decodeIfPresent(Double.self, forKey: .longitude)
        self.temperature = try container.decode(Double.self, forKey: .temperature)
        self.condition = try container.decode(String.self, forKey: .condition)
        self.highTemperature = try container.decode(Double.self, forKey: .highTemperature)
        self.lowTemperature = try container.decode(Double.self, forKey: .lowTemperature)
        self.feelsLike = try container.decodeIfPresent(Double.self, forKey: .feelsLike) ?? self.temperature
        self.weatherSymbolName = try container.decodeIfPresent(String.self, forKey: .weatherSymbolName) ?? "cloud.sun.fill"
        self.description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
        self.humidity = try container.decodeIfPresent(Int.self, forKey: .humidity) ?? 0
        self.dewPoint = try container.decodeIfPresent(Double.self, forKey: .dewPoint) ?? self.temperature
        self.windSpeed = try container.decodeIfPresent(Double.self, forKey: .windSpeed) ?? 0
        self.windDirection = try container.decodeIfPresent(String.self, forKey: .windDirection) ?? ""
        self.precipitationChance = try container.decodeIfPresent(Int.self, forKey: .precipitationChance) ?? 0
        self.uvIndex = try container.decodeIfPresent(Int.self, forKey: .uvIndex) ?? 0
        self.uvDescription = try container.decodeIfPresent(String.self, forKey: .uvDescription) ?? ""
        self.visibility = try container.decodeIfPresent(Double.self, forKey: .visibility) ?? 10
        self.visibilityDescription = try container.decodeIfPresent(String.self, forKey: .visibilityDescription) ?? ""
        self.pressure = try container.decodeIfPresent(Double.self, forKey: .pressure) ?? 1013.25
        self.pressureTrend = try container.decodeIfPresent(String.self, forKey: .pressureTrend) ?? ""
        self.alert = try container.decodeIfPresent(WeatherAlert.self, forKey: .alert)
        self.hourlyForecast = try container.decodeIfPresent([HourlyWeather].self, forKey: .hourlyForecast) ?? []
        self.dailyForecast = try container.decodeIfPresent([DailyWeather].self, forKey: .dailyForecast) ?? []
        self.rainWindow = try container.decodeIfPresent(RainWindow.self, forKey: .rainWindow)
        self.warmingInsight = try container.decodeIfPresent(String.self, forKey: .warmingInsight) ?? ""
        self.chanceOfRain = try container.decodeIfPresent(Int.self, forKey: .chanceOfRain) ?? 0
        self.sunrise = try container.decodeIfPresent(String.self, forKey: .sunrise) ?? ""
        self.sunset = try container.decodeIfPresent(String.self, forKey: .sunset) ?? ""
        self.fetchTimestamp = try container.decodeIfPresent(Date.self, forKey: .fetchTimestamp) ?? Date()
        self.isCached = try container.decodeIfPresent(Bool.self, forKey: .isCached) ?? false
        self.locationStatus = try container.decodeIfPresent(LocationStatus.self, forKey: .locationStatus) ?? .live
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(cityName, forKey: .cityName)
        try container.encode(locationSubtitle, forKey: .locationSubtitle)
        try container.encode(latitude, forKey: .latitude)
        try container.encode(longitude, forKey: .longitude)
        try container.encode(temperature, forKey: .temperature)
        try container.encode(condition, forKey: .condition)
        try container.encode(highTemperature, forKey: .highTemperature)
        try container.encode(lowTemperature, forKey: .lowTemperature)
        try container.encode(feelsLike, forKey: .feelsLike)
        try container.encode(weatherSymbolName, forKey: .weatherSymbolName)
        try container.encode(description, forKey: .description)
        try container.encode(humidity, forKey: .humidity)
        try container.encode(dewPoint, forKey: .dewPoint)
        try container.encode(windSpeed, forKey: .windSpeed)
        try container.encode(windDirection, forKey: .windDirection)
        try container.encode(precipitationChance, forKey: .precipitationChance)
        try container.encode(uvIndex, forKey: .uvIndex)
        try container.encode(uvDescription, forKey: .uvDescription)
        try container.encode(visibility, forKey: .visibility)
        try container.encode(visibilityDescription, forKey: .visibilityDescription)
        try container.encode(pressure, forKey: .pressure)
        try container.encode(pressureTrend, forKey: .pressureTrend)
        try container.encode(alert, forKey: .alert)
        try container.encode(hourlyForecast, forKey: .hourlyForecast)
        try container.encode(dailyForecast, forKey: .dailyForecast)
        try container.encode(rainWindow, forKey: .rainWindow)
        try container.encode(warmingInsight, forKey: .warmingInsight)
        try container.encode(chanceOfRain, forKey: .chanceOfRain)
        try container.encode(sunrise, forKey: .sunrise)
        try container.encode(sunset, forKey: .sunset)
        try container.encode(fetchTimestamp, forKey: .fetchTimestamp)
        try container.encode(isCached, forKey: .isCached)
        try container.encode(locationStatus, forKey: .locationStatus)
    }

    public func asCached(isCached: Bool = true) -> Weather {
        Weather(
            cityName: self.cityName,
            locationSubtitle: self.locationSubtitle,
            latitude: self.latitude,
            longitude: self.longitude,
            temperature: self.temperature,
            condition: self.condition,
            highTemperature: self.highTemperature,
            lowTemperature: self.lowTemperature,
            feelsLike: self.feelsLike,
            weatherSymbolName: self.weatherSymbolName,
            description: self.description,
            humidity: self.humidity,
            dewPoint: self.dewPoint,
            windSpeed: self.windSpeed,
            windDirection: self.windDirection,
            precipitationChance: self.precipitationChance,
            uvIndex: self.uvIndex,
            uvDescription: self.uvDescription,
            visibility: self.visibility,
            visibilityDescription: self.visibilityDescription,
            pressure: self.pressure,
            pressureTrend: self.pressureTrend,
            alert: self.alert,
            hourlyForecast: self.hourlyForecast,
            dailyForecast: self.dailyForecast,
            rainWindow: self.rainWindow,
            warmingInsight: self.warmingInsight,
            chanceOfRain: self.chanceOfRain,
            sunrise: self.sunrise,
            sunset: self.sunset,
            fetchTimestamp: self.fetchTimestamp,
            isCached: isCached,
            locationStatus: self.locationStatus
        )
    }

    public var isDaylight: Bool {
        if let firstHourly = hourlyForecast.first {
            return firstHourly.isDaylight
        }
        let sym = weatherSymbolName.lowercased()
        if sym.contains("moon") {
            return false
        }
        return true
    }

    public func withCityName(_ newName: String, subtitle: String? = nil, status: LocationStatus? = nil) -> Weather {
        Weather(
            cityName: newName,
            locationSubtitle: subtitle ?? self.locationSubtitle,
            latitude: self.latitude,
            longitude: self.longitude,
            temperature: self.temperature,
            condition: self.condition,
            highTemperature: self.highTemperature,
            lowTemperature: self.lowTemperature,
            feelsLike: self.feelsLike,
            weatherSymbolName: self.weatherSymbolName,
            description: self.description,
            humidity: self.humidity,
            dewPoint: self.dewPoint,
            windSpeed: self.windSpeed,
            windDirection: self.windDirection,
            precipitationChance: self.precipitationChance,
            uvIndex: self.uvIndex,
            uvDescription: self.uvDescription,
            visibility: self.visibility,
            visibilityDescription: self.visibilityDescription,
            pressure: self.pressure,
            pressureTrend: self.pressureTrend,
            alert: self.alert,
            hourlyForecast: self.hourlyForecast,
            dailyForecast: self.dailyForecast,
            rainWindow: self.rainWindow,
            warmingInsight: self.warmingInsight,
            chanceOfRain: self.chanceOfRain,
            sunrise: self.sunrise,
            sunset: self.sunset,
            fetchTimestamp: self.fetchTimestamp,
            isCached: self.isCached,
            locationStatus: status ?? self.locationStatus
        )
    }

    public func withStatus(_ status: LocationStatus) -> Weather {
        withCityName(self.cityName, subtitle: self.locationSubtitle, status: status)
    }
}

// MARK: - WidgetSnapshot + Weather Extension

extension WidgetSnapshot {
    public init(from weather: Weather, updatedAt: Date = Date()) {
        let city = weather.cityName.isEmpty ? "UpThere" : weather.cityName
        let temp = Int(round(weather.temperature))
        let feelsLike = Int(round(weather.feelsLike))
        let high = Int(round(weather.highTemperature))
        let low = Int(round(weather.lowTemperature))
        let condition = weather.condition.isEmpty ? "Partly Cloudy" : weather.condition
        let symbolName = weather.weatherSymbolName.isEmpty ? "cloud.sun.fill" : weather.weatherSymbolName
        let rainChance = max(0, min(100, weather.chanceOfRain))

        let rainInsight: String
        if let window = weather.rainWindow, !window.title.isEmpty {
            rainInsight = "\(window.title) · \(rainChance)%"
        } else if rainChance > 0 {
            rainInsight = "\(rainChance)% chance of rain today"
        } else {
            rainInsight = "No rain expected today"
        }

        let calendar = Calendar.current
        let currentHour = calendar.component(.hour, from: updatedAt)

        let hourly: [WidgetHourlySnapshot] = weather.hourlyForecast.prefix(12).enumerated().map { idx, h in
            let itemHour = calendar.component(.hour, from: h.date)
            let timeLabel: String
            if idx == 0 || itemHour == currentHour {
                timeLabel = "Now"
            } else {
                let df = DateFormatter()
                df.locale = Locale(identifier: "en_US")
                df.dateFormat = "ha"
                timeLabel = df.string(from: h.date)
            }
            return WidgetHourlySnapshot(
                id: h.id.uuidString,
                time: timeLabel,
                temp: Int(round(h.temperature)),
                symbol: h.symbolName.isEmpty ? "cloud.sun.fill" : h.symbolName,
                rainProb: max(0, min(100, Int(round(h.precipitationChance * 100)))),
                date: h.date
            )
        }

        let daily: [WidgetDailySnapshot] = weather.dailyForecast.prefix(5).enumerated().map { idx, d in
            let dayLabel = idx == 0 ? "Today" : d.dayName
            return WidgetDailySnapshot(
                id: d.id.uuidString,
                day: dayLabel,
                symbol: d.symbolName.isEmpty ? "cloud.sun.fill" : d.symbolName,
                low: Int(round(d.lowTemperature)),
                high: Int(round(d.highTemperature)),
                rainProb: max(0, min(100, Int(round(d.precipitationProbability * 100))))
            )
        }

        self.init(
            city: city,
            latitude: weather.latitude,
            longitude: weather.longitude,
            temp: temp,
            feelsLike: feelsLike,
            high: high,
            low: low,
            condition: condition,
            symbolName: symbolName,
            rainChance: rainChance,
            rainInsight: rainInsight,
            hourly: hourly,
            daily: daily,
            updatedAt: updatedAt,
            locationStatus: weather.locationStatus
        )
    }
}

// MARK: - Pure WeatherKit -> Domain Weather Mapper

public enum WeatherKitMapper {
    public static func mapToDomain(
        weather: WeatherKit.Weather,
        cityName: String,
        locationSubtitle: String = "",
        coordinate: CLLocationCoordinate2D? = nil,
        locationStatus: LocationStatus = .live
    ) -> Weather {
        let current = weather.currentWeather

        let rawTemp = current.temperature.converted(to: .celsius).value
        let currentTemp = (rawTemp.isNaN || rawTemp.isInfinite) ? 20.0 : rawTemp.rounded()

        let rawFeelsLike = current.apparentTemperature.converted(to: .celsius).value
        let feelsLikeTemp = (rawFeelsLike.isNaN || rawFeelsLike.isInfinite) ? currentTemp : rawFeelsLike.rounded()

        let todayDaily = weather.dailyForecast.first
        let rawHigh = todayDaily?.highTemperature.converted(to: .celsius).value ?? currentTemp
        let rawLow = todayDaily?.lowTemperature.converted(to: .celsius).value ?? currentTemp

        let highTemp = max(rawHigh.rounded(), rawLow.rounded())
        let lowTemp = min(rawHigh.rounded(), rawLow.rounded())

        let humidityPercent = max(0, min(100, Int((current.humidity * 100).rounded())))
        let dewPointTemp = current.dewPoint.converted(to: .celsius).value.rounded()
        let windSpeedKmh = max(0, current.wind.speed.converted(to: .kilometersPerHour).value.rounded())
        let windDirString = "From \(current.wind.compassDirection.description.lowercased())"

        let uvVal = max(0, current.uvIndex.value)
        let uvCat = current.uvIndex.category.description

        let visKm = max(0.0, current.visibility.converted(to: .kilometers).value.rounded())
        let condLower = current.condition.description.lowercased()
        let isRainyCondition = condLower.contains("rain") || condLower.contains("drizzle") ||
            condLower.contains("shower") || condLower.contains("storm")
        let visDesc: String
        if isRainyCondition {
            visDesc = "Reduced by precipitation"
        } else if visKm >= 10 {
            visDesc = "Good"
        } else if visKm >= 5 {
            visDesc = "Moderate"
        } else {
            visDesc = "Poor"
        }

        let pressHpa = max(800.0, min(1100.0, current.pressure.converted(to: .hectopascals).value.rounded()))
        let pressTrend: String
        switch current.pressureTrend {
        case .rising:  pressTrend = "Rising"
        case .falling: pressTrend = "Falling"
        case .steady:  pressTrend = "Steady"
        @unknown default: pressTrend = "Steady"
        }

        let calendar = Calendar.current
        let now = Date()

        let filteredHours = weather.hourlyForecast.filter { $0.date >= now.addingTimeInterval(-1800) }
        let mappedHourly: [HourlyWeather] = filteredHours.prefix(16).map { hour in
            let hourTemp = hour.temperature.converted(to: .celsius).value.rounded()
            let hourFeelsLike = hour.apparentTemperature.converted(to: .celsius).value.rounded()
            let precipChance = max(0.0, min(1.0, hour.precipitationChance))
            let precipAmount = max(0.0, hour.precipitationAmount.converted(to: .millimeters).value)
            let hourSymbol = hour.symbolName.isEmpty ? "cloud.sun.fill" : hour.symbolName
            let windSpeed = max(0.0, hour.wind.speed.converted(to: .kilometersPerHour).value.rounded())
            let windGust = max(windSpeed, hour.wind.gust?.converted(to: .kilometersPerHour).value.rounded() ?? windSpeed)
            let uv = max(0, hour.uvIndex.value)
            let cloud = max(0.0, min(1.0, hour.cloudCover))
            let daylight = hour.isDaylight

            return HourlyWeather(
                date: hour.date,
                temperature: hourTemp,
                feelsLike: hourFeelsLike,
                precipitationChance: precipChance,
                precipitationAmount: precipAmount,
                windSpeed: windSpeed,
                windGust: windGust,
                uvIndex: uv,
                cloudCover: cloud,
                symbolName: hourSymbol,
                isDaylight: daylight
            )
        }

        let dayFormatter = DateFormatter()
        dayFormatter.locale = Locale(identifier: "en_US")
        dayFormatter.dateFormat = "EEE"

        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US")
        dateFormatter.dateFormat = "d MMM"

        let mappedDaily: [DailyWeather] = weather.dailyForecast.prefix(10).enumerated().map { index, day in
            let dayName: String
            if calendar.isDateInToday(day.date) {
                dayName = "Today"
            } else {
                dayName = dayFormatter.string(from: day.date)
            }
            let dateString = dateFormatter.string(from: day.date)
            let low = day.lowTemperature.converted(to: .celsius).value.rounded()
            let high = day.highTemperature.converted(to: .celsius).value.rounded()
            let symbol = day.symbolName.isEmpty ? "cloud.sun.fill" : day.symbolName

            return DailyWeather(
                dayName: dayName,
                date: dateString,
                symbolName: symbol,
                precipitationProbability: day.precipitationChance,
                lowTemperature: min(low, high),
                highTemperature: max(low, high)
            )
        }

        var mappedAlert: WeatherAlert?
        if let alert = weather.weatherAlerts?.first, alert.metadata.expirationDate > Date() {
            let untilFormatter = DateFormatter()
            untilFormatter.locale = Locale(identifier: "en_US")
            untilFormatter.dateFormat = "h:mm a"
            let validUntilStr = "Until \(untilFormatter.string(from: alert.metadata.expirationDate))"
            mappedAlert = WeatherAlert(
                source: alert.source,
                title: alert.summary,
                validUntil: validUntilStr,
                details: alert.summary,
                severity: String(describing: alert.severity),
                expirationDate: alert.metadata.expirationDate
            )
        }

        let sunTimeFormatter = DateFormatter()
        sunTimeFormatter.locale = Locale(identifier: "en_US")
        sunTimeFormatter.dateFormat = "h:mm a"
        let sunriseStr = todayDaily?.sun.sunrise.map { sunTimeFormatter.string(from: $0) } ?? "6:00 AM"
        let sunsetStr = todayDaily?.sun.sunset.map { sunTimeFormatter.string(from: $0) } ?? "6:00 PM"

        let todayRainChance = max(0, min(100, Int(((todayDaily?.precipitationChance ?? 0) * 100).rounded())))
        let safeSymbol = current.symbolName.isEmpty ? "cloud.sun.fill" : current.symbolName
        let conditionDesc: String = {
            let raw = current.condition.description.trimmingCharacters(in: .whitespacesAndNewlines)
            if raw.isEmpty { return "Partly Cloudy" }
            if raw.lowercased() == "mostly clear" && safeSymbol.contains("cloud") {
                return "Partly Cloudy"
            }
            return raw
        }()

        var computedRainWindow: RainWindow? = nil
        let weatherDesc: String = {
            let timeFmt = DateFormatter()
            timeFmt.locale = Locale(identifier: "en_US")
            timeFmt.dateFormat = "ha"

            var sentenceParts: [String] = []

            // Cloud change
            if mappedHourly.count >= 2, let first = mappedHourly.first {
                let initialCover = first.cloudCover
                for hour in mappedHourly.dropFirst() {
                    let diff = hour.cloudCover - initialCover
                    if diff >= 0.35 {
                        let changeTime = timeFmt.string(from: hour.date)
                        sentenceParts.append("Cloud cover increasing around \(changeTime).")
                        break
                    } else if diff <= -0.35 {
                        let changeTime = timeFmt.string(from: hour.date)
                        sentenceParts.append("Skies clearing around \(changeTime).")
                        break
                    }
                }
            }

            // Rain window
            let rainyHours = mappedHourly.filter { $0.precipitationChance >= 0.30 }
            if let firstRain = rainyHours.first,
               let maxRain = rainyHours.max(by: { $0.precipitationChance < $1.precipitationChance }) {
                let lastRain = rainyHours.last ?? firstRain
                let sTime = timeFmt.string(from: firstRain.date)
                let eTime = timeFmt.string(from: lastRain.date)
                let prob = Int((maxRain.precipitationChance * 100).rounded())
                if sTime == eTime {
                    sentenceParts.append("Rain likely around \(sTime) (\(prob)% chance).")
                } else {
                    sentenceParts.append("Rain expected between \(sTime) and \(eTime) (\(prob)% chance).")
                }
                computedRainWindow = RainWindow(
                    title: "Rain likely around \(sTime)",
                    timeRange: "\(sTime) – \(eTime)",
                    detail: "\(prob)% chance of rain."
                )
            }

            // Wind
            if let maxWind = mappedHourly.max(by: { $0.windGust < $1.windGust }), maxWind.windGust >= 20 || maxWind.windSpeed >= 20 {
                let windTime = timeFmt.string(from: maxWind.date)
                let gustVal = Int(maxWind.windGust.rounded())
                sentenceParts.append("Wind gusts up to \(gustVal) km/h around \(windTime).")
            } else if let firstWind = mappedHourly.first, firstWind.windSpeed > 0 {
                let speedVal = Int(firstWind.windSpeed.rounded())
                sentenceParts.append("Gentle winds around \(speedVal) km/h.")
            }

            if sentenceParts.isEmpty {
                return "\(conditionDesc) conditions throughout the day."
            }

            return sentenceParts.joined(separator: " ")
        }()

        return Weather(
            cityName: cityName,
            locationSubtitle: locationSubtitle,
            latitude: coordinate?.latitude,
            longitude: coordinate?.longitude,
            temperature: currentTemp,
            condition: conditionDesc,
            highTemperature: highTemp,
            lowTemperature: lowTemp,
            feelsLike: feelsLikeTemp,
            weatherSymbolName: safeSymbol,
            description: weatherDesc,
            humidity: humidityPercent,
            dewPoint: dewPointTemp,
            windSpeed: windSpeedKmh,
            windDirection: windDirString,
            precipitationChance: todayRainChance,
            uvIndex: uvVal,
            uvDescription: uvCat,
            visibility: visKm,
            visibilityDescription: visDesc,
            pressure: pressHpa,
            pressureTrend: pressTrend,
            alert: mappedAlert,
            hourlyForecast: mappedHourly,
            dailyForecast: mappedDaily,
            rainWindow: computedRainWindow,
            warmingInsight: "",
            chanceOfRain: todayRainChance,
            sunrise: sunriseStr,
            sunset: sunsetStr,
            fetchTimestamp: Date(),
            isCached: false,
            locationStatus: locationStatus
        )
    }
}

// MARK: - Widget Weather Fetching Protocol & Live Implementation

public protocol WidgetWeatherFetching: Sendable {
    func fetchWeather(for location: CLLocation, cityName: String) async throws -> Weather
}

public final class LiveWidgetWeatherFetcher: WidgetWeatherFetching {
    private let weatherService: WeatherService

    public init(weatherService: WeatherService? = nil) {
        self.weatherService = weatherService ?? .shared
    }

    public func fetchWeather(for location: CLLocation, cityName: String) async throws -> Weather {
        let rawWeather = try await weatherService.weather(for: location)
        return WeatherKitMapper.mapToDomain(
            weather: rawWeather,
            cityName: cityName,
            locationSubtitle: "",
            coordinate: location.coordinate
        )
    }
}

// MARK: - Weather Widget Timeline Provider

public struct WeatherWidgetTimelineProvider: TimelineProvider {
    public let weatherFetcher: WidgetWeatherFetching
    public let snapshotStore: WidgetSnapshotStore

    public init(
        weatherFetcher: WidgetWeatherFetching = LiveWidgetWeatherFetcher(),
        snapshotStore: WidgetSnapshotStore = .shared
    ) {
        self.weatherFetcher = weatherFetcher
        self.snapshotStore = snapshotStore
    }

    public func placeholder(in context: Context) -> WeatherWidgetEntry {
        .preview
    }

    public func getSnapshot(in context: Context, completion: @escaping (WeatherWidgetEntry) -> Void) {
        if context.isPreview {
            completion(.preview)
        } else {
            let snapshot = snapshotStore.load()
            completion(WeatherWidgetEntry(from: snapshot))
        }
    }

    public func getTimeline(in context: Context, completion: @escaping (Timeline<WeatherWidgetEntry>) -> Void) {
        Task {
            let timeline = await loadTimeline()
            completion(timeline)
        }
    }

    public func loadTimeline() async -> Timeline<WeatherWidgetEntry> {
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date().addingTimeInterval(30 * 60)
        guard let savedSnapshot = snapshotStore.load() else {
            // If no snapshot exists (the app was never opened), show "Open UpThere to set your location" state
            let emptyEntry = WeatherWidgetEntry.empty
            return Timeline(entries: [emptyEntry], policy: .after(nextUpdate))
        }

        guard let lat = savedSnapshot.latitude, let lon = savedSnapshot.longitude else {
            let fallbackEntry = WeatherWidgetEntry(from: savedSnapshot, isStale: false)
            return Timeline(entries: [fallbackEntry], policy: .after(nextUpdate))
        }

        let location = CLLocation(latitude: lat, longitude: lon)
        do {
            let weather = try await weatherFetcher.fetchWeather(for: location, cityName: savedSnapshot.city)
            let newSnapshot = WidgetSnapshot(from: weather)
            do {
                try snapshotStore.save(newSnapshot)
            } catch {
                let logger = Logger(subsystem: "com.vedanshi.upthereapp", category: "WeatherWidgetTimeline")
                logger.error("Failed to save widget snapshot: \(error.localizedDescription)")
            }

            let entries = makeHourlyEntries(from: newSnapshot)
            return Timeline(entries: entries, policy: .after(nextUpdate))
        } catch {
            let logger = Logger(subsystem: "com.vedanshi.upthereapp", category: "WeatherWidgetTimeline")
            logger.error("Failed to fetch weather for widget timeline: \(error.localizedDescription)")
            // If the fetch fails, fall back to the saved snapshot and show "Updated h:mm a"
            let fallbackEntry = WeatherWidgetEntry(from: savedSnapshot, isStale: true)
            return Timeline(entries: [fallbackEntry], policy: .after(nextUpdate))
        }
    }

    public func makeHourlyEntries(from snapshot: WidgetSnapshot) -> [WeatherWidgetEntry] {
        let now = Date()
        var entries: [WeatherWidgetEntry] = [
            WeatherWidgetEntry(from: snapshot, date: now, isStale: false)
        ]

        let futureHours = snapshot.hourly.filter { item in
            if let d = item.date {
                return d > now
            }
            return false
        }

        for (index, hourItem) in futureHours.prefix(4).enumerated() {
            guard let entryDate = hourItem.date else { continue }
            let remainingHourly = Array(futureHours.dropFirst(index))
            let hourlyEntry = WeatherWidgetEntry(
                date: entryDate,
                cityName: snapshot.city,
                condition: snapshot.condition,
                temperature: hourItem.temp,
                feelsLike: hourItem.temp,
                high: snapshot.high,
                low: snapshot.low,
                rainChance: hourItem.rainProb,
                symbolName: hourItem.symbol,
                rainInsight: snapshot.rainInsight,
                hourly: remainingHourly,
                daily: snapshot.daily,
                isStale: false,
                isEmpty: false,
                updatedAtText: nil
            )
            entries.append(hourlyEntry)
        }

        return entries
    }
}
