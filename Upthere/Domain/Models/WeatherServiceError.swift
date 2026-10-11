import Foundation

public enum WeatherServiceError: LocalizedError, Equatable, Sendable {
    case offline
    case timeout
    case unauthorized
    case rateLimited
    case serverError(code: Int)
    case dataUnavailable
    case corruptedData(String)

    public var errorDescription: String? {
        switch self {
        case .offline:
            return "No internet connection. Please check your network and try again."
        case .timeout:
            return "The weather request timed out. Please try again."
        case .unauthorized:
            return "Unauthorized: WeatherKit authorization failed. Please check App ID and entitlements."
        case .rateLimited:
            return "Weather service rate limit reached. Please wait a moment."
        case .serverError(let code):
            return "Weather service unavailable (Error \(code)). Please try again later."
        case .dataUnavailable:
            return "No weather data is currently available for this location."
        case .corruptedData(let details):
            return "Unable to parse weather data: \(details)"
        }
    }

    public var isRetryable: Bool {
        switch self {
        case .offline, .timeout, .serverError, .rateLimited:
            return true
        case .unauthorized, .dataUnavailable, .corruptedData:
            return false
        }
    }
}
