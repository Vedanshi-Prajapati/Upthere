import Foundation

public struct Weather: Equatable, Sendable, Codable {
    // MARK: - Core
    public let cityName: String
    public let locationSubtitle: String
    public let temperature: Double
    public let condition: String
    public let highTemperature: Double
    public let lowTemperature: Double
    public let feelsLike: Double
    public let weatherSymbolName: String

    // MARK: - Description
    public let description: String

    // MARK: - Metrics
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

    // MARK: - Alert
    public let alert: WeatherAlert?

    // MARK: - Hourly & Daily Forecasts
    public let hourlyForecast: [HourlyWeather]
    public let dailyForecast: [DailyWeather]

    // MARK: - Insights
    public let rainWindow: RainWindow?
    public let warmingInsight: String

    // MARK: - Today Summary
    public let chanceOfRain: Int
    public let sunrise: String
    public let sunset: String

    // MARK: - Freshness Metadata
    public let fetchTimestamp: Date
    public let isCached: Bool

    public init(
        cityName: String,
        locationSubtitle: String = "",
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
        isCached: Bool = false
    ) {
        self.cityName = cityName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.locationSubtitle = locationSubtitle.trimmingCharacters(in: .whitespacesAndNewlines)

        // Validate temperatures (prevent NaN, Infinity)
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

        // Clamp metrics to physically valid ranges
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

        // Exclude expired alerts
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
    }

    public func asCached(isCached: Bool = true) -> Weather {
        Weather(
            cityName: self.cityName,
            locationSubtitle: self.locationSubtitle,
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
            isCached: isCached
        )
    }
}
