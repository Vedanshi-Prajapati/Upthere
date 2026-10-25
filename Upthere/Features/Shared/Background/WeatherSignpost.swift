import Foundation
import OSLog

enum WeatherSignpost {
    static let logger = Logger(subsystem: "com.vedanshi.upthereapp", category: "WeatherBackground")
    static let signposter = OSSignposter(logger: logger)
}
