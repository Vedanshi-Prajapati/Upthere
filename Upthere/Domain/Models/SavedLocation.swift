import Foundation

struct SavedLocation: Equatable, Sendable, Identifiable, Codable {
    let id: UUID
    let cityName: String
    let regionName: String
    let condition: String
    let isCurrentLocation: Bool
    let latitude: Double?
    let longitude: Double?

    init(
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
