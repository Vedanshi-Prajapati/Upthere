import Foundation

public struct SavedLocation: Equatable, Sendable, Identifiable {
    public let id: UUID
    public let cityName: String
    public let regionName: String
    public let condition: String
    public let isCurrentLocation: Bool

    public init(
        id: UUID = UUID(),
        cityName: String,
        regionName: String,
        condition: String,
        isCurrentLocation: Bool = false
    ) {
        self.id = id
        self.cityName = cityName
        self.regionName = regionName
        self.condition = condition
        self.isCurrentLocation = isCurrentLocation
    }
}
