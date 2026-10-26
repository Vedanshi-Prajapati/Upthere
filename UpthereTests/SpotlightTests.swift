import Testing
import Foundation
import CoreLocation
import AppIntents
import SwiftUI
import WidgetKit
@testable import Upthere

@Suite("Spotlight Tests")
@MainActor
struct SpotlightTests {

    // MARK: - Spotlight identifier resolution
    @Test("Spotlight service resolves city name from identifier")
    func spotlightResolution() {
        let weatherCity = SpotlightService.shared.resolveCityName(from: "weather.cupertino")
        #expect(weatherCity == "Cupertino")

        let locationCity = SpotlightService.shared.resolveCityName(from: "location.tokyo")
        #expect(locationCity == "Tokyo")

        let multiWordCity = SpotlightService.shared.resolveCityName(from: "weather.san_francisco")
        #expect(multiWordCity == "San Francisco")
    }


    // MARK: - App Intents LocationEntityQuery
    @Test("LocationEntityQuery returns entities")
    func locationEntityQuery() async throws {
        let query = LocationEntityQuery()
        let entities = try await query.allEntities()

        #expect(!entities.isEmpty, "Location entities should contain at least current location")
        #expect(entities.first?.id == "current", "First entity should be Current Location")
    }

}
