import Foundation
import OSLog

public enum WeatherSignpost {
    public static let logger = Logger(subsystem: "com.vedanshi.upthereapp", category: "WeatherBackground")
    public static let signposter = OSSignposter(logger: logger)
}
