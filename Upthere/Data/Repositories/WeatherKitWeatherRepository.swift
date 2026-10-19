import Foundation
import CoreLocation
import WeatherKit
import os

@MainActor
public final class WeatherKitWeatherRepository: WeatherRepository {
    private let weatherService: WeatherService
    private let locationService: LocationService
    private let cacheManager: WeatherCacheManager

    public init(
        weatherService: WeatherService? = nil,
        locationService: LocationService? = nil,
        cacheManager: WeatherCacheManager? = nil
    ) {
        self.weatherService = weatherService ?? .shared
        self.locationService = locationService ?? .shared
        self.cacheManager = cacheManager ?? .shared
    }

    public func fetchCurrentWeather() async throws -> Weather {
        let location: CLLocation
        let cityName: String
        let subtitle: String

        do {
            let userLoc = try await locationService.requestCurrentLocation(force: true)
            location = userLoc
            let geo = await locationService.reverseGeocode(location: userLoc)
            cityName = geo.cityName
            subtitle = geo.subtitle
        } catch {
            // Fall back strictly to Ghaziabad, Uttar Pradesh, India when device location cannot be obtained
            location = LocationService.fallbackCoordinate
            cityName = LocationService.fallbackCityName
            let reason: String
            if let locError = error as? LocationServiceError {
                switch locError {
                case .servicesDisabled:
                    reason = "Location Services disabled"
                case .permissionDenied:
                    reason = "Location permission denied"
                case .restricted:
                    reason = "Location restricted"
                case .timeout:
                    reason = "Location timed out"
                case .invalidCoordinates:
                    reason = "Invalid coordinates"
                }
            } else {
                reason = "Location unavailable"
            }
            subtitle = "Default location · \(reason)"
        }

        return try await fetchWeather(for: location, cityName: cityName, locationSubtitle: subtitle)
    }

    public func fetchWeather(
        for location: CLLocation,
        cityName: String,
        locationSubtitle: String
    ) async throws -> Weather {
        guard locationService.isValidCoordinate(location.coordinate) else {
            throw WeatherServiceError.corruptedData("Invalid coordinates provided")
        }

        let cacheKey = cacheManager.cacheKey(
            for: cityName,
            coordinate: (lat: location.coordinate.latitude, lon: location.coordinate.longitude)
        )

        do {
            let spID = AppSignposts.shared.weatherSignposter.makeSignpostID()
            let spState = AppSignposts.shared.weatherSignposter.beginInterval("WeatherServiceNetworkCall", id: spID)
            let rawWeather = try await weatherService.weather(for: location)
            AppSignposts.shared.weatherSignposter.endInterval("WeatherServiceNetworkCall", spState)
            let mapped = mapToDomain(
                weather: rawWeather,
                cityName: cityName,
                locationSubtitle: locationSubtitle
            )
            cacheManager.save(weather: mapped, key: cacheKey)
            return mapped
        } catch {
            let mappedError = mapWeatherKitError(error)

            // If a valid cache exists, return it with isCached = true
            if let cached = cacheManager.load(key: cacheKey, allowExpired: true) {
                return cached.weather.asCached(isCached: true)
            }

            throw mappedError
        }
    }

    // MARK: - Mapping WeatherKit -> Domain Weather

    private func mapToDomain(
        weather: WeatherKit.Weather,
        cityName: String,
        locationSubtitle: String
    ) -> Weather {
        let current = weather.currentWeather

        // Validate temperature
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

        // Hourly mapping (next 16 hours, chronological)
        let calendar = Calendar.current
        let now = Date()
        let timeFormatter = DateFormatter()
        timeFormatter.locale = Locale(identifier: "en_US")
        timeFormatter.dateFormat = "ha" // e.g. "9AM", "12PM"

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

        // Daily mapping (up to 10 days)
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

        // Alert mapping (ignore expired alerts)
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

        // Sunrise & Sunset (handle polar missing dates)
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
            // If condition says "Mostly Clear" but the symbol is a cloud-sun/cloud-moon glyph, align to "Partly Cloudy"
            if raw.lowercased() == "mostly clear" && safeSymbol.contains("cloud") {
                return "Partly Cloudy"
            }
            return raw
        }()

        // Build concise description sentence from InsightEngine results: next change, rain window, wind
        let weatherDesc: String = {
            let engine = InsightEngine()
            let timeFmt = DateFormatter()
            timeFmt.locale = Locale(identifier: "en_US")
            timeFmt.dateFormat = "ha"

            var sentenceParts: [String] = []

            // 1. Next change
            if let cloud = engine.cloudChange(from: mappedHourly) {
                let changeTime = timeFmt.string(from: cloud.changeDate)
                if cloud.isClearing {
                    sentenceParts.append("Skies clearing around \(changeTime).")
                } else {
                    sentenceParts.append("Cloud cover increasing around \(changeTime).")
                }
            }

            // 2. Rain window
            if let rain = engine.rainWindow(from: mappedHourly) {
                let sTime = timeFmt.string(from: rain.startDate)
                let eTime = timeFmt.string(from: rain.endDate)
                let prob = Int((rain.peakProbability * 100).rounded())
                if sTime == eTime {
                    sentenceParts.append("Rain likely around \(sTime) (\(prob)% chance).")
                } else {
                    sentenceParts.append("Rain expected between \(sTime) and \(eTime) (\(prob)% chance).")
                }
            }

            // 3. Wind
            if let wind = engine.strongestWind(from: mappedHourly), wind.peakGust >= 20 || wind.peakWindSpeed >= 20 {
                let windTime = timeFmt.string(from: wind.peakDate)
                let gustVal = Int(wind.peakGust.rounded())
                sentenceParts.append("Wind gusts up to \(gustVal) km/h around \(windTime).")
            } else if let wind = engine.strongestWind(from: mappedHourly), wind.currentWindSpeed > 0 {
                let speedVal = Int(wind.currentWindSpeed.rounded())
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
            rainWindow: nil,
            warmingInsight: "",
            chanceOfRain: todayRainChance,
            sunrise: sunriseStr,
            sunset: sunsetStr,
            fetchTimestamp: Date(),
            isCached: false
        )
    }

    private func mapWeatherKitError(_ error: Error) -> WeatherServiceError {
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            if nsError.code == NSURLErrorTimedOut {
                return .timeout
            }
            if nsError.code == NSURLErrorNotConnectedToInternet || nsError.code == NSURLErrorNetworkConnectionLost {
                return .offline
            }
        }

        let desc = error.localizedDescription.lowercased()
        if desc.contains("unauthorized") || desc.contains("401") || desc.contains("403") {
            return .unauthorized
        }
        if desc.contains("rate limit") || desc.contains("429") {
            return .rateLimited
        }
        if desc.contains("timeout") {
            return .timeout
        }
        return .serverError(code: nsError.code)
    }
}
