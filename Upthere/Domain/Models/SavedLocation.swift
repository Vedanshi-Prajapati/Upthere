import Foundation

public struct SavedLocation: Equatable, Sendable, Identifiable, Codable {
    public let id: UUID
    public let cityName: String
    public let regionName: String
    public let condition: String
    public let isCurrentLocation: Bool
    public let latitude: Double?
    public let longitude: Double?

    public init(
        id: UUID = UUID(),
        cityName: String,
        regionName: String,
        condition: String,
        isCurrentLocation: Bool = false,
        latitude: Double? = nil,
        longitude: Double? = nil
    ) {
        self.id = id
        self.cityName = cityName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.regionName = regionName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.condition = condition

        // Validate coordinate bounds
        if let lat = latitude, let lon = longitude,
           lat.isFinite, lon.isFinite,
           lat >= -90.0, lat <= 90.0,
           lon >= -180.0, lon <= 180.0 {
            self.latitude = lat
            self.longitude = lon
        } else {
            self.latitude = nil
            self.longitude = nil
        }
        self.isCurrentLocation = isCurrentLocation
    }
}
