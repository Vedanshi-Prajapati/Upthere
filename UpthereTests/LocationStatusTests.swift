import Testing
import Foundation
import CoreLocation
@testable import Upthere

@Suite("LocationStatus Tests")
struct LocationStatusTests {

    @Test("Status mapping for every LocationServiceError")
    func statusMappingForEveryLocationServiceError() {
        #expect(LocationStatus.from(LocationServiceError.permissionDenied) == .denied)
        #expect(LocationStatus.from(LocationServiceError.restricted) == .restricted)
        #expect(LocationStatus.from(LocationServiceError.servicesDisabled) == .servicesDisabled)
        #expect(LocationStatus.from(LocationServiceError.timeout) == .timedOut)
        #expect(LocationStatus.from(LocationServiceError.invalidCoordinates) == .unavailable)

        // General error mapping
        struct RandomError: Error {}
        #expect(LocationStatus.from(RandomError()) == .unavailable)
        #expect(LocationStatus.from(nil as Error?) == .live)
    }

    @Test("Banner copy for each status")
    func bannerCopyForEachStatus() {
        // live and savedCity have no banner
        #expect(LocationStatus.live.bannerCopy == nil)
        #expect(LocationStatus.live.bannerAction == nil)

        #expect(LocationStatus.savedCity.bannerCopy == nil)
        #expect(LocationStatus.savedCity.bannerAction == nil)

        // denied
        #expect(LocationStatus.denied.bannerCopy == "Location access is off. Using Ghaziabad. Open Settings")
        #expect(LocationStatus.denied.bannerAction == .openSettings)

        // timedOut
        #expect(LocationStatus.timedOut.bannerCopy == "Couldn't get your location. Using Ghaziabad. Retry")
        #expect(LocationStatus.timedOut.bannerAction == .retry)

        // servicesDisabled
        #expect(LocationStatus.servicesDisabled.bannerCopy == "Location services are disabled. Using Ghaziabad. Open Settings")
        #expect(LocationStatus.servicesDisabled.bannerAction == .openSettings)

        // restricted
        #expect(LocationStatus.restricted.bannerCopy == "Location access is restricted. Using Ghaziabad. Open Settings")
        #expect(LocationStatus.restricted.bannerAction == .openSettings)

        // unavailable
        #expect(LocationStatus.unavailable.bannerCopy == "Location is unavailable. Using Ghaziabad. Retry")
        #expect(LocationStatus.unavailable.bannerAction == .retry)
    }

    @Test("Fake geocoder that never returns still yields loaded weather named Current Location")
    func fakeGeocoderNeverReturnsStillYieldsCurrentLocation() async {
        let (mockDefaults, suiteName) = makeIsolatedDefaults()
        defer { mockDefaults.removePersistentDomain(forName: suiteName) }

        final class HangingGeocoder: GeocoderProtocol, Sendable {
            func reverseGeocode(location: CLLocation) async throws -> String? {
                try? await Task.sleep(nanoseconds: 100_000_000_000)
                return nil
            }
        }

        let fakeManager = FakeLocationManager()
        let hangingGeocoder = HangingGeocoder()

        let locationService = LocationService(
            manager: fakeManager,
            isLocationServicesEnabledProvider: { true },
            geocodeTimeout: .milliseconds(50),
            geocoder: hangingGeocoder
        )

        let testLocation = CLLocation(latitude: 33.1234, longitude: 44.5678)
        fakeManager.onRequestLocation = { [weak locationService] in
            let dummy = CLLocationManager()
            locationService?.locationManager(dummy, didUpdateLocations: [testLocation])
        }

        let locManager = SavedLocationsManager(defaults: mockDefaults)
        let repo = MockWeatherRepository()
        let useCase = GetWeatherUseCase(repository: repo)
        let vm = HomeViewModel(
            getWeatherUseCase: useCase,
            locationsManager: locManager,
            locationService: locationService,
            defaults: mockDefaults
        )

        await vm.loadWeather(force: true)

        guard case .loaded(let weather, _) = vm.state else {
            Issue.record("Expected state to be .loaded, but was \(vm.state)")
            return
        }

        #expect(weather.cityName == "Current Location")
        #expect(vm.displayedWeather?.cityName == "Current Location")
        #expect(weather.locationStatus == .live)
    }

    @Test("Locations row subtitle says Current GPS location only for status == .live, otherwise Default location")
    func locationsRowSubtitleSaysCurrentGPSLocationOnlyForLive() {
        let (mockDefaults, suiteName) = makeIsolatedDefaults()
        defer { mockDefaults.removePersistentDomain(forName: suiteName) }

        let locManager = SavedLocationsManager(defaults: mockDefaults)

        // Case 1: Status is live
        let liveSubtitle: String = (LocationStatus.live == .live) ? "Current GPS location" : "Default location"
        locManager.updateCurrentLocationHeader(cityName: "San Francisco", subtitle: liveSubtitle)
        #expect(locManager.locations.first?.regionName == "Current GPS location")

        // Case 2: Status is denied
        let deniedSubtitle: String = (LocationStatus.denied == .live) ? "Current GPS location" : "Default location"
        locManager.updateCurrentLocationHeader(cityName: "Ghaziabad", subtitle: deniedSubtitle)
        #expect(locManager.locations.first?.regionName == "Default location")

        // Case 3: Status is timedOut
        let timedOutSubtitle: String = (LocationStatus.timedOut == .live) ? "Current GPS location" : "Default location"
        locManager.updateCurrentLocationHeader(cityName: "Ghaziabad", subtitle: timedOutSubtitle)
        #expect(locManager.locations.first?.regionName == "Default location")

        // Case 4: Status is servicesDisabled
        let disabledSubtitle: String = (LocationStatus.servicesDisabled == .live) ? "Current GPS location" : "Default location"
        locManager.updateCurrentLocationHeader(cityName: "Ghaziabad", subtitle: disabledSubtitle)
        #expect(locManager.locations.first?.regionName == "Default location")
    }

    @Test("HomeViewModel derives locationFallback banner with correct message and action for denied and timedOut")
    func homeViewModelDerivesBannersFromLocationStatus() async {
        let (mockDefaults, suiteName) = makeIsolatedDefaults()
        defer { mockDefaults.removePersistentDomain(forName: suiteName) }

        let base = MockWeatherRepository.makeGhaziabadWeather()

        // 1. Denied
        let deniedWeather = base.withStatus(.denied)
        let repoDenied = MockWeatherRepository(mockWeather: deniedWeather)
        let fakeManagerDenied = FakeLocationManager()
        fakeManagerDenied.authorizationStatus = .denied
        let locServiceDenied = LocationService(manager: fakeManagerDenied)
        let vmDenied = HomeViewModel(
            getWeatherUseCase: GetWeatherUseCase(repository: repoDenied),
            locationService: locServiceDenied,
            defaults: mockDefaults
        )
        await vmDenied.loadWeather(force: true)
        if case .loaded(_, let banner) = vmDenied.state {
            #expect(banner == .locationFallback(message: "Location access is off. Using Ghaziabad. Open Settings", action: .openSettings))
        } else {
            Issue.record("Expected .loaded with banner")
        }

        // 2. TimedOut
        let timedOutWeather = base.withStatus(.timedOut)
        let repoTimedOut = MockWeatherRepository(mockWeather: timedOutWeather)
        let fakeManagerTimedOut = FakeLocationManager()
        fakeManagerTimedOut.authorizationStatus = .denied
        let locServiceTimedOut = LocationService(manager: fakeManagerTimedOut)
        let vmTimedOut = HomeViewModel(
            getWeatherUseCase: GetWeatherUseCase(repository: repoTimedOut),
            locationService: locServiceTimedOut,
            defaults: mockDefaults
        )
        await vmTimedOut.loadWeather(force: true)
        if case .loaded(_, let banner) = vmTimedOut.state {
            #expect(banner == .locationFallback(message: "Couldn't get your location. Using Ghaziabad. Retry", action: .retry))
        } else {
            Issue.record("Expected .loaded with banner")
        }

        // 3. Live has no banner
        let liveWeather = base.withStatus(.live)
        let repoLive = MockWeatherRepository(mockWeather: liveWeather)
        let vmLive = HomeViewModel(
            getWeatherUseCase: GetWeatherUseCase(repository: repoLive),
            defaults: mockDefaults
        )
        await vmLive.loadWeather(force: true)
        if case .loaded(_, let banner) = vmLive.state {
            #expect(banner == nil)
        } else {
            Issue.record("Expected .loaded with nil banner")
        }

        // 4. SavedCity has no banner
        let savedCityWeather = base.withStatus(.savedCity)
        let repoSavedCity = MockWeatherRepository(mockWeather: savedCityWeather)
        let vmSavedCity = HomeViewModel(
            getWeatherUseCase: GetWeatherUseCase(repository: repoSavedCity),
            defaults: mockDefaults
        )
        await vmSavedCity.loadWeather(force: true)
        if case .loaded(_, let banner) = vmSavedCity.state {
            #expect(banner == nil)
        } else {
            Issue.record("Expected .loaded with nil banner")
        }
    }
}
