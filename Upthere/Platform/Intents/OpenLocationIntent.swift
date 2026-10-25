import Foundation
import AppIntents

/// AppIntent to deep link into UpThere and display a specific location
struct OpenLocationIntent: AppIntent, OpenIntent {
    static let title: LocalizedStringResource = "Open Location in UpThere"
    static let description = IntentDescription("Open UpThere directly to a specific city's forecast.")
    static let openAppWhenRun: Bool = true

    @Parameter(title: "Target Location")
    var target: LocationEntity

    init() {}

    init(target: LocationEntity) {
        self.target = target
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        let city = target.name
        let region = target.region
        let lat = target.latitude
        let lon = target.longitude

        let saved = SavedLocation(
            cityName: city,
            regionName: region,
            condition: "Loading",
            isCurrentLocation: target.id == "current",
            latitude: lat,
            longitude: lon
        )
        SavedLocationsManager.shared.selectLocation(saved)

        return .result()
    }
}
