import Foundation

public struct Weather: Equatable, Sendable {
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

    // MARK: - Hourly Forecast
    public let hourlyForecast: [HourlyWeather]

    // MARK: - Insights
    public let rainWindow: RainWindow?
    public let warmingInsight: String

    // MARK: - Today Summary
    public let chanceOfRain: Int
    public let sunrise: String
    public let sunset: String

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
        rainWindow: RainWindow? = nil,
        warmingInsight: String = "",
        chanceOfRain: Int = 0,
        sunrise: String = "",
        sunset: String = ""
    ) {
        self.cityName = cityName
        self.locationSubtitle = locationSubtitle
        self.temperature = temperature
        self.condition = condition
        self.highTemperature = highTemperature
        self.lowTemperature = lowTemperature
        self.feelsLike = feelsLike
        self.weatherSymbolName = weatherSymbolName
        self.description = description
        self.humidity = humidity
        self.dewPoint = dewPoint
        self.windSpeed = windSpeed
        self.windDirection = windDirection
        self.precipitationChance = precipitationChance
        self.uvIndex = uvIndex
        self.uvDescription = uvDescription
        self.visibility = visibility
        self.visibilityDescription = visibilityDescription
        self.pressure = pressure
        self.pressureTrend = pressureTrend
        self.alert = alert
        self.hourlyForecast = hourlyForecast
        self.rainWindow = rainWindow
        self.warmingInsight = warmingInsight
        self.chanceOfRain = chanceOfRain
        self.sunrise = sunrise
        self.sunset = sunset
    }
}
