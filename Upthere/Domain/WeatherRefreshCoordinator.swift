import Foundation
import os

@MainActor
protocol WeatherRefreshCoordinating: AnyObject {
    func handleSuccessfulRefresh(_ weather: Weather) async
}

@MainActor
final class WeatherRefreshCoordinator: WeatherRefreshCoordinating {
    private let widgetSnapshotWriter: any WidgetSnapshotWriting
    private let spotlightIndexer: any SpotlightIndexing
    private let rainActivityUpdater: any RainActivityUpdating
    private let notificationScheduler: any NotificationScheduling
    private let fetchMetrics: any FetchMetrics
    private let defaults: UserDefaults
    private let logger = Logger(subsystem: "com.vedanshi.upthereapp", category: "WeatherRefreshCoordinator")

    init(
        widgetSnapshotWriter: any WidgetSnapshotWriting,
        spotlightIndexer: any SpotlightIndexing,
        rainActivityUpdater: any RainActivityUpdating,
        notificationScheduler: any NotificationScheduling,
        fetchMetrics: any FetchMetrics,
        defaults: UserDefaults
    ) {
        self.widgetSnapshotWriter = widgetSnapshotWriter
        self.spotlightIndexer = spotlightIndexer
        self.rainActivityUpdater = rainActivityUpdater
        self.notificationScheduler = notificationScheduler
        self.fetchMetrics = fetchMetrics
        self.defaults = defaults
    }

    func handleSuccessfulRefresh(_ weather: Weather) async {
        // 1. Save widget snapshot (log errors, no try?)
        let snapshot = WidgetSnapshot(from: weather)
        do {
            try widgetSnapshotWriter.save(snapshot)
        } catch {
            logger.error("Failed to save widget snapshot: \(error.localizedDescription)")
        }

        // 2. Reload widget timelines
        widgetSnapshotWriter.reloadAllTimelines()

        // 3. Spotlight index if enabled
        let isSpotlightEnabled = defaults.object(forKey: AppGroup.spotlightEnabledKey) as? Bool ?? true
        if isSpotlightEnabled {
            await spotlightIndexer.indexWeather(weather)
        }

        // 4. Live Activity update
        await rainActivityUpdater.updateOnForegroundRefresh(
            hourly: weather.hourlyForecast,
            city: weather.cityName
        )

        // 5. Notification scheduling
        let rainEnabled = defaults.bool(forKey: AppGroup.rainAlertsKey)
        let severeEnabled = defaults.bool(forKey: AppGroup.severeAlertsKey)
        await notificationScheduler.handleWeatherRefresh(
            weather: weather,
            rainAlertsEnabled: rainEnabled,
            severeAlertsEnabled: severeEnabled,
            now: Date()
        )

        // 6. Metrics
        fetchMetrics.recordWeatherFetch()
    }
}

final class NoOpWidgetSnapshotWriter: WidgetSnapshotWriting {
    init() {}
    func save(_ snapshot: WidgetSnapshot) throws {}
    func reloadAllTimelines() {}
}

final class NoOpSpotlightIndexer: SpotlightIndexing {
    init() {}
    func indexWeather(_ weather: Weather) async {}
}

final class NoOpRainActivityUpdater: RainActivityUpdating {
    init() {}
    func updateOnForegroundRefresh(hourly: [HourlyWeather], city: String?) async {}
}

final class NoOpFetchMetrics: FetchMetrics {
    init() {}
    func recordWeatherFetch() {}
}
