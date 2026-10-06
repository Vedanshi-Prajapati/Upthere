import Foundation
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
    private let getWeatherUseCase: any GetWeatherUseCaseProtocol

    public init(getWeatherUseCase: any GetWeatherUseCaseProtocol) {
        self.getWeatherUseCase = getWeatherUseCase
    }

    public func loadWeather() async {
        if case .loading = state { return }
        if case .loaded = state { return }
        state = .loading
        do {
            let weather = try await getWeatherUseCase.execute()
            state = .loaded(weather)
        } catch {
            state = .error(error.localizedDescription)
        }
    }
}
