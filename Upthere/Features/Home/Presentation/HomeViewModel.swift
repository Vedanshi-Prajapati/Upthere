import Foundation
import CoreLocation
import Observation

@Observable
@MainActor
public final class HomeViewModel {
    public enum ViewState: Equatable {
        case idle
        case loading
        case loaded(Weather)
        case error(String)
    }

    public private(set) var state: ViewState = .idle
    public private(set) var selectedLocation: SavedLocation?
    private let getWeatherUseCase: any GetWeatherUseCaseProtocol

    public init(getWeatherUseCase: any GetWeatherUseCaseProtocol) {
        self.getWeatherUseCase = getWeatherUseCase

        // Automatically reload when GPS coordinates change in Simulator or device
        LocationService.shared.onLocationChanged = { [weak self] _ in
            guard let self = self else { return }
            if self.selectedLocation == nil {
                Task { @MainActor in
                    await self.loadWeather(force: true)
                }
            }
        }
    }

    public func selectLocation(_ location: SavedLocation?) {
        if let location = location, !location.isCurrentLocation {
            self.selectedLocation = location
        } else {
            self.selectedLocation = nil
        }
        Task {
            await loadWeather(force: true)
        }
    }

    public func loadWeather(force: Bool = false) async {
        if case .loading = state { return }
        if !force, case .loaded = state { return }
        state = .loading
        do {
            let weather: Weather
            if let selected = selectedLocation, let lat = selected.latitude, let lon = selected.longitude {
                let clLocation = CLLocation(latitude: lat, longitude: lon)
                let subtitle = selected.regionName.isEmpty ? "Selected location" : selected.regionName
                weather = try await getWeatherUseCase.execute(for: clLocation, cityName: selected.cityName, subtitle: subtitle)
            } else {
                weather = try await getWeatherUseCase.execute()
            }
            state = .loaded(weather)
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    public func refreshWeather() async {
        await loadWeather(force: true)
    }
}
