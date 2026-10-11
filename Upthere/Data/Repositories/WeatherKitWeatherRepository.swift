import Foundation
import CoreLocation
import WeatherKit

@MainActor
public final class WeatherKitWeatherRepository: WeatherRepository {
    private let weatherService: WeatherService
    private let locationService: LocationService

    public init(
        weatherService: WeatherService = .shared,
        locationService: LocationService? = nil
    ) {
        self.weatherService = weatherService
        self.locationService = locationService ?? .shared
    }

    public func fetchCurrentWeather() async throws -> Weather {
        let location: CLLocation
        let cityName: String
        let subtitle: String

        do {
            let userLoc = try await locationService.requestCurrentLocation()
            location = userLoc
            let geo = await locationService.reverseGeocode(location: userLoc)
            cityName = geo.cityName
            subtitle = geo.subtitle
        } catch {
            // Fall back to default location (Ghaziabad) if location permission is not available or denied
            location = LocationService.defaultCoordinate
            let geo = await locationService.reverseGeocode(location: location)
            cityName = geo.cityName.isEmpty ? LocationService.defaultCityName : geo.cityName
            subtitle = geo.subtitle
        }

        return try await fetchWeather(for: location, cityName: cityName, locationSubtitle: subtitle)
    }

    public func fetchWeather(
        for location: CLLocation,
        cityName: String,
        locationSubtitle: String
    ) async throws -> Weather {
        let weather = try await weatherService.weather(for: location)
        return mapToDomain(weather: weather, cityName: cityName, locationSubtitle: locationSubtitle)
    }

    // MARK: - Mapping WeatherKit -> Domain Weather

    private func mapToDomain(
        weather: WeatherKit.Weather,
        cityName: String,
        locationSubtitle: String
    ) -> Weather {
        let current = weather.currentWeather
        let currentTemp = current.temperature.converted(to: .celsius).value.rounded()
        let feelsLikeTemp = current.apparentTemperature.converted(to: .celsius).value.rounded()

        let todayDaily = weather.dailyForecast.first
        let highTemp = todayDaily?.highTemperature.converted(to: .celsius).value.rounded() ?? currentTemp
        let lowTemp = todayDaily?.lowTemperature.converted(to: .celsius).value.rounded() ?? currentTemp

        let humidityPercent = Int((current.humidity * 100).rounded())
        let dewPointTemp = current.dewPoint.converted(to: .celsius).value.rounded()
        let windSpeedKmh = current.wind.speed.converted(to: .kilometersPerHour).value.rounded()
        let windDirString = "From \(current.wind.compassDirection.description.lowercased())"

        let uvVal = current.uvIndex.value
        let uvCat = current.uvIndex.category.description

        let visKm = current.visibility.converted(to: .kilometers).value.rounded()
        let visDesc: String
        if visKm >= 10 {
            visDesc = "Clear"
        } else if visKm >= 5 {
            visDesc = "Moderate"
        } else {
            visDesc = "Haze"
        }

        let pressHpa = current.pressure.converted(to: .hectopascals).value.rounded()
        let pressTrend: String
        switch current.pressureTrend {
        case .rising:  pressTrend = "Rising"
        case .falling: pressTrend = "Falling"
        case .steady:  pressTrend = "Steady"
        @unknown default: pressTrend = "Steady"
        }

        // Hourly mapping (next 16 hours)
        let calendar = Calendar.current
        let now = Date()
        let timeFormatter = DateFormatter()
        timeFormatter.locale = Locale(identifier: "en_US")
        timeFormatter.dateFormat = "ha" // e.g. "9AM", "12PM"

        let filteredHours = weather.hourlyForecast.filter { $0.date >= now.addingTimeInterval(-1800) }
        let mappedHourly: [HourlyWeather] = filteredHours.prefix(16).enumerated().map { index, hour in
            let timeString: String
            if index == 0 {
                timeString = "Now"
            } else {
                let formatted = timeFormatter.string(from: hour.date).lowercased() // "9am"
                timeString = formatted.replacingOccurrences(of: "m", with: "") // "9a"
            }
            return HourlyWeather(
                time: timeString,
                temperature: hour.temperature.converted(to: .celsius).value.rounded(),
                precipitationProbability: hour.precipitationChance
            )
        }

        // Daily mapping (up to 10 days)
        let dayFormatter = DateFormatter()
        dayFormatter.locale = Locale(identifier: "en_US")
        dayFormatter.dateFormat = "EEE" // "Wed"

        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US")
        dateFormatter.dateFormat = "d MMM" // "7 Oct"

        let mappedDaily: [DailyWeather] = weather.dailyForecast.prefix(10).enumerated().map { index, day in
            let dayName: String
            if calendar.isDateInToday(day.date) {
                dayName = "Today"
            } else {
                dayName = dayFormatter.string(from: day.date)
            }
            let dateString = dateFormatter.string(from: day.date)
            return DailyWeather(
                dayName: dayName,
                date: dateString,
                symbolName: day.symbolName,
                precipitationProbability: day.precipitationChance,
                lowTemperature: day.lowTemperature.converted(to: .celsius).value.rounded(),
                highTemperature: day.highTemperature.converted(to: .celsius).value.rounded()
            )
        }

        // Alert mapping
        var mappedAlert: WeatherAlert?
        if let alert = weather.weatherAlerts?.first {
            let untilFormatter = DateFormatter()
            untilFormatter.locale = Locale(identifier: "en_US")
            untilFormatter.dateFormat = "h:mm a"
            let validUntilStr = "Until \(untilFormatter.string(from: alert.metadata.expirationDate))"
            mappedAlert = WeatherAlert(
                source: alert.source,
                title: alert.summary,
                validUntil: validUntilStr
            )
        }

        // Rain Window calculation
        let rainWindow = calculateRainWindow(from: mappedHourly)

        // Warming insight calculation
        let warmingInsight = calculateWarmingInsight(from: mappedHourly)

        // Sunrise & Sunset
        let sunTimeFormatter = DateFormatter()
        sunTimeFormatter.locale = Locale(identifier: "en_US")
        sunTimeFormatter.dateFormat = "h:mm a"
        let sunriseStr = todayDaily?.sun.sunrise.map { sunTimeFormatter.string(from: $0) } ?? "6:00 AM"
        let sunsetStr = todayDaily?.sun.sunset.map { sunTimeFormatter.string(from: $0) } ?? "6:00 PM"

        let todayRainChance = Int(((todayDaily?.precipitationChance ?? 0) * 100).rounded())
        let conditionDesc = current.condition.description
        let weatherDesc = "\(conditionDesc) conditions today with a high of \(Int(highTemp))° and a low of \(Int(lowTemp))°."

        return Weather(
            cityName: cityName,
            locationSubtitle: locationSubtitle,
            temperature: currentTemp,
            condition: conditionDesc,
            highTemperature: highTemp,
            lowTemperature: lowTemp,
            feelsLike: feelsLikeTemp,
            weatherSymbolName: current.symbolName,
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
            rainWindow: rainWindow,
            warmingInsight: warmingInsight,
            chanceOfRain: todayRainChance,
            sunrise: sunriseStr,
            sunset: sunsetStr
        )
    }

    private func calculateRainWindow(from hourly: [HourlyWeather]) -> RainWindow? {
        let rainyHours = hourly.filter { $0.precipitationProbability >= 0.3 }
        guard let firstRain = rainyHours.first, let maxRain = rainyHours.max(by: { $0.precipitationProbability < $1.precipitationProbability }) else {
            return nil
        }
        let lastRain = rainyHours.last ?? firstRain
        let peakPercent = Int((maxRain.precipitationProbability * 100).rounded())

        let timeRange: String
        if firstRain.time == lastRain.time {
            timeRange = "Around \(firstRain.time)"
        } else {
            timeRange = "\(firstRain.time) – \(lastRain.time)"
        }

        return RainWindow(
            title: "Rain likely later",
            timeRange: timeRange,
            detail: "Most likely near \(maxRain.time), at \(peakPercent)% probability."
        )
    }

    private func calculateWarmingInsight(from hourly: [HourlyWeather]) -> String {
        guard hourly.count >= 4 else { return "" }
        let morning = hourly[0]
        if let peak = hourly.prefix(8).max(by: { $0.temperature < $1.temperature }), peak.temperature > morning.temperature {
            let diff = Int((peak.temperature - morning.temperature).rounded())
            if diff >= 2 {
                return "+\(diff)° warming from \(morning.time) to \(peak.time)"
            }
        }
        return ""
    }
}
