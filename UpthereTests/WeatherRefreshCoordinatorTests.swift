import Testing
import Foundation
import CoreLocation
@testable import Upthere

// MARK: - Test Fakes

/// Lock-protected fake writer for recording snapshot saves and reloads.
/// Invariant: Access to saved snapshots, reload count, and simulated error is synchronized via `lock`.
final class FakeWidgetSnapshotWriter: WidgetSnapshotWriting, @unchecked Sendable {
    private let lock = NSLock()
    private var _savedSnapshots: [WidgetSnapshot] = []
    private var _reloadCount = 0
    private var _errorToThrow: Error?

    var savedSnapshots: [WidgetSnapshot] {
        get { lock.withLock { _savedSnapshots } }
        set { lock.withLock { _savedSnapshots = newValue } }
    }

    var reloadCount: Int {
        get { lock.withLock { _reloadCount } }
        set { lock.withLock { _reloadCount = newValue } }
    }

    var errorToThrow: Error? {
        get { lock.withLock { _errorToThrow } }
        set { lock.withLock { _errorToThrow = newValue } }
    }

    func save(_ snapshot: WidgetSnapshot) throws {
        try lock.withLock {
            if let error = _errorToThrow {
                throw error
            }
            _savedSnapshots.append(snapshot)
        }
    }

    func reloadAllTimelines() {
        lock.withLock {
            _reloadCount += 1
        }
    }
}

/// Lock-protected fake spotlight indexer recording indexed weather instances.
/// Invariant: Access to `indexedWeathers` is synchronized via `lock`.
final class FakeSpotlightIndexer: SpotlightIndexing, @unchecked Sendable {
    private let lock = NSLock()
    private var _indexedWeathers: [Weather] = []

    var indexedWeathers: [Weather] {
        get { lock.withLock { _indexedWeathers } }
        set { lock.withLock { _indexedWeathers = newValue } }
    }

    func indexWeather(_ weather: Weather) async {
        lock.withLock {
            _indexedWeathers.append(weather)
        }
    }
}

/// Lock-protected fake rain activity updater recording update calls.
/// Invariant: Access to `updateCalls` is synchronized via `lock`.
final class FakeRainActivityUpdater: RainActivityUpdating, @unchecked Sendable {
    private let lock = NSLock()
    private var _updateCalls: [(hourly: [HourlyWeather], city: String?)] = []

    var updateCalls: [(hourly: [HourlyWeather], city: String?)] {
        get { lock.withLock { _updateCalls } }
        set { lock.withLock { _updateCalls = newValue } }
    }

    func updateOnForegroundRefresh(hourly: [HourlyWeather], city: String?) async {
        lock.withLock {
            _updateCalls.append((hourly, city))
        }
    }
}

/// Lock-protected spy notification scheduler recording refresh and schedule calls.
/// Invariant: Access to recorded refresh calls and scheduled requests is synchronized via `lock`.
final class SpyNotificationScheduler: NotificationScheduling, @unchecked Sendable {
    private let lock = NSLock()
    private var _handleRefreshCalls: [(weather: Weather, rainEnabled: Bool, severeEnabled: Bool, now: Date)] = []
    private var _scheduledRequests: [LocalNotificationRequest] = []

    var handleRefreshCalls: [(weather: Weather, rainEnabled: Bool, severeEnabled: Bool, now: Date)] {
        get { lock.withLock { _handleRefreshCalls } }
        set { lock.withLock { _handleRefreshCalls = newValue } }
    }

    var scheduledRequests: [LocalNotificationRequest] {
        get { lock.withLock { _scheduledRequests } }
        set { lock.withLock { _scheduledRequests = newValue } }
    }

    func requestAuthorization() async -> Bool { true }
    func authorizationStatus() async -> NotificationAuthorizationStatus { .authorized }
    func schedule(_ request: LocalNotificationRequest) async throws {
        lock.withLock {
            _scheduledRequests.append(request)
        }
    }
    func cancel(id: String) async {}
    func cancelAll() async {}
    func isAlertDelivered(id: String) -> Bool { false }
    func markAlertDelivered(id: String) {}

    func handleWeatherRefresh(
        weather: Weather,
        rainAlertsEnabled: Bool,
        severeAlertsEnabled: Bool,
        now: Date
    ) async {
        lock.withLock {
            _handleRefreshCalls.append((weather, rainAlertsEnabled, severeAlertsEnabled, now))
        }
    }
}

/// Lock-protected fake fetch metrics counter.
/// Invariant: Access to `recordFetchCount` is synchronized via `lock`.
final class FakeFetchMetrics: FetchMetrics, @unchecked Sendable {
    private let lock = NSLock()
    private var _recordFetchCount = 0

    var recordFetchCount: Int {
        get { lock.withLock { _recordFetchCount } }
        set { lock.withLock { _recordFetchCount = newValue } }
    }

    func recordWeatherFetch() {
        lock.withLock {
            _recordFetchCount += 1
        }
    }
}

// MARK: - Test Suite

@Suite("WeatherRefreshCoordinator Tests")
@MainActor
struct WeatherRefreshCoordinatorTests {

    @Test("Coordinator runs all side effects once per refresh through HomeViewModel")
    func coordinatorRunsAllSideEffectsOncePerRefresh() async {
        let (mockDefaults, suiteName) = makeIsolatedDefaults()
        defer { mockDefaults.removePersistentDomain(forName: suiteName) }

        let writer = FakeWidgetSnapshotWriter()
        let indexer = FakeSpotlightIndexer()
        let rainUpdater = FakeRainActivityUpdater()
        let scheduler = SpyNotificationScheduler()
        let metrics = FakeFetchMetrics()

        let coordinator = WeatherRefreshCoordinator(
            widgetSnapshotWriter: writer,
            spotlightIndexer: indexer,
            rainActivityUpdater: rainUpdater,
            notificationScheduler: scheduler,
            fetchMetrics: metrics,
            defaults: mockDefaults
        )

        let repo = MockWeatherRepository(delayNanoseconds: 0)
        let useCase = GetWeatherUseCase(repository: repo)
        let locManager = SavedLocationsManager(defaults: mockDefaults)

        let vm = HomeViewModel(
            getWeatherUseCase: useCase,
            refreshCoordinator: coordinator,
            locationsManager: locManager,
            defaults: mockDefaults
        )

        await vm.loadWeather(force: true)

        #expect(writer.savedSnapshots.count == 1)
        #expect(writer.reloadCount == 1)
        #expect(indexer.indexedWeathers.count == 1)
        #expect(rainUpdater.updateCalls.count == 1)
        #expect(scheduler.handleRefreshCalls.count == 1)
        #expect(metrics.recordFetchCount == 1)
    }

    @Test("Coordinator handleSuccessfulRefresh runs all side effects once and logs widget error without throwing")
    func coordinatorHandlesSuccessfulRefreshDirectly() async {
        let (mockDefaults, suiteName) = makeIsolatedDefaults()
        defer { mockDefaults.removePersistentDomain(forName: suiteName) }

        let writer = FakeWidgetSnapshotWriter()
        writer.errorToThrow = NSError(domain: "test", code: -1, userInfo: nil)
        let indexer = FakeSpotlightIndexer()
        let rainUpdater = FakeRainActivityUpdater()
        let scheduler = SpyNotificationScheduler()
        let metrics = FakeFetchMetrics()

        let coordinator = WeatherRefreshCoordinator(
            widgetSnapshotWriter: writer,
            spotlightIndexer: indexer,
            rainActivityUpdater: rainUpdater,
            notificationScheduler: scheduler,
            fetchMetrics: metrics,
            defaults: mockDefaults
        )

        let weather = MockWeatherRepository.makeGhaziabadWeather()
        await coordinator.handleSuccessfulRefresh(weather)

        #expect(writer.savedSnapshots.isEmpty)
        #expect(writer.reloadCount == 1)
        #expect(indexer.indexedWeathers.count == 1)
        #expect(rainUpdater.updateCalls.count == 1)
        #expect(scheduler.handleRefreshCalls.count == 1)
        #expect(metrics.recordFetchCount == 1)
    }

    @Test("No coordinator side effects run when fetch fails")
    func noSideEffectsRunOnFailure() async {
        let (mockDefaults, suiteName) = makeIsolatedDefaults()
        defer { mockDefaults.removePersistentDomain(forName: suiteName) }

        let writer = FakeWidgetSnapshotWriter()
        let indexer = FakeSpotlightIndexer()
        let rainUpdater = FakeRainActivityUpdater()
        let scheduler = SpyNotificationScheduler()
        let metrics = FakeFetchMetrics()

        let coordinator = WeatherRefreshCoordinator(
            widgetSnapshotWriter: writer,
            spotlightIndexer: indexer,
            rainActivityUpdater: rainUpdater,
            notificationScheduler: scheduler,
            fetchMetrics: metrics,
            defaults: mockDefaults
        )

        let repo = MockWeatherRepository(shouldFail: true, delayNanoseconds: 0)
        let useCase = GetWeatherUseCase(repository: repo)
        let locManager = SavedLocationsManager(defaults: mockDefaults)

        let vm = HomeViewModel(
            getWeatherUseCase: useCase,
            refreshCoordinator: coordinator,
            locationsManager: locManager,
            defaults: mockDefaults
        )

        await vm.loadWeather(force: true)

        #expect(writer.savedSnapshots.isEmpty)
        #expect(writer.reloadCount == 0)
        #expect(indexer.indexedWeathers.isEmpty)
        #expect(rainUpdater.updateCalls.isEmpty)
        #expect(scheduler.handleRefreshCalls.isEmpty)
        #expect(metrics.recordFetchCount == 0)
    }

    @Test("No coordinator side effects run when load is cancelled")
    func noSideEffectsRunOnCancellation() async {
        let (mockDefaults, suiteName) = makeIsolatedDefaults()
        defer { mockDefaults.removePersistentDomain(forName: suiteName) }

        let writer = FakeWidgetSnapshotWriter()
        let indexer = FakeSpotlightIndexer()
        let rainUpdater = FakeRainActivityUpdater()
        let scheduler = SpyNotificationScheduler()
        let metrics = FakeFetchMetrics()

        let coordinator = WeatherRefreshCoordinator(
            widgetSnapshotWriter: writer,
            spotlightIndexer: indexer,
            rainActivityUpdater: rainUpdater,
            notificationScheduler: scheduler,
            fetchMetrics: metrics,
            defaults: mockDefaults
        )

        let repo = MockWeatherRepository(delayNanoseconds: 1_000_000_000)
        let useCase = GetWeatherUseCase(repository: repo)
        let locManager = SavedLocationsManager(defaults: mockDefaults)

        let vm = HomeViewModel(
            getWeatherUseCase: useCase,
            refreshCoordinator: coordinator,
            locationsManager: locManager,
            defaults: mockDefaults
        )

        let loadTask = Task {
            await vm.loadWeather(force: true)
        }
        try? await Task.sleep(nanoseconds: 20_000_000)
        vm.activeTask?.cancel()
        loadTask.cancel()
        await loadTask.value

        #expect(writer.savedSnapshots.isEmpty)
        #expect(writer.reloadCount == 0)
        #expect(indexer.indexedWeathers.isEmpty)
        #expect(rainUpdater.updateCalls.isEmpty)
        #expect(scheduler.handleRefreshCalls.isEmpty)
        #expect(metrics.recordFetchCount == 0)
    }

    @Test("No coordinator side effects run for a stale request id")
    func noSideEffectsRunForStaleRequestId() async {
        let (mockDefaults, suiteName) = makeIsolatedDefaults()
        defer { mockDefaults.removePersistentDomain(forName: suiteName) }

        let writer = FakeWidgetSnapshotWriter()
        let indexer = FakeSpotlightIndexer()
        let rainUpdater = FakeRainActivityUpdater()
        let scheduler = SpyNotificationScheduler()
        let metrics = FakeFetchMetrics()

        let coordinator = WeatherRefreshCoordinator(
            widgetSnapshotWriter: writer,
            spotlightIndexer: indexer,
            rainActivityUpdater: rainUpdater,
            notificationScheduler: scheduler,
            fetchMetrics: metrics,
            defaults: mockDefaults
        )

        /// Lock-protected test repository simulating slow first fetch and fast second fetch.
        /// Invariant: `callCount` access and increment are protected by `lock`.
        final class FirstSlowSecondFastRepository: WeatherRepository, @unchecked Sendable {
            private let lock = NSLock()
            private var _callCount = 0

            func fetchCurrentWeather() async throws -> Weather {
                let count = lock.withLock { () -> Int in
                    _callCount += 1
                    return _callCount
                }
                if count == 1 {
                    try await Task.sleep(nanoseconds: 200_000_000)
                    return MockWeatherRepository.makeGhaziabadWeather().withCityName("Stale City")
                } else {
                    return MockWeatherRepository.makeGhaziabadWeather().withCityName("Fresh City")
                }
            }

            func fetchWeather(
                for location: CLLocation,
                cityName: String,
                locationSubtitle: String
            ) async throws -> Weather {
                let count = lock.withLock { () -> Int in
                    _callCount += 1
                    return _callCount
                }
                if count == 1 {
                    try await Task.sleep(nanoseconds: 200_000_000)
                    return MockWeatherRepository.makeGhaziabadWeather().withCityName("Stale City")
                } else {
                    return MockWeatherRepository.makeGhaziabadWeather().withCityName("Fresh City")
                }
            }
        }

        let repo = FirstSlowSecondFastRepository()
        let useCase = GetWeatherUseCase(repository: repo)
        let locManager = SavedLocationsManager(defaults: mockDefaults)

        let vm = HomeViewModel(
            getWeatherUseCase: useCase,
            refreshCoordinator: coordinator,
            locationsManager: locManager,
            defaults: mockDefaults
        )

        // Launch slow first request
        let firstTask = Task {
            await vm.loadWeather(force: true)
        }

        // Brief delay to ensure first request is in flight
        try? await Task.sleep(nanoseconds: 30_000_000)

        // Launch second request which generates a newer latestRequestId and cancels the first
        await vm.loadWeather(force: true)
        await firstTask.value

        // Only the second request should have invoked the coordinator side effects
        #expect(writer.savedSnapshots.count == 1)
        #expect(writer.savedSnapshots.first?.city == "Fresh City")
        #expect(indexer.indexedWeathers.count == 1)
        #expect(indexer.indexedWeathers.first?.cityName == "Fresh City")
        #expect(metrics.recordFetchCount == 1)
    }

    @Test("Spotlight indexing is skipped when spotlightEnabledKey is false")
    func spotlightIsSkippedWhenDisabled() async {
        let (mockDefaults, suiteName) = makeIsolatedDefaults()
        defer { mockDefaults.removePersistentDomain(forName: suiteName) }

        mockDefaults.set(false, forKey: AppGroup.spotlightEnabledKey)

        let writer = FakeWidgetSnapshotWriter()
        let indexer = FakeSpotlightIndexer()
        let rainUpdater = FakeRainActivityUpdater()
        let scheduler = SpyNotificationScheduler()
        let metrics = FakeFetchMetrics()

        let coordinator = WeatherRefreshCoordinator(
            widgetSnapshotWriter: writer,
            spotlightIndexer: indexer,
            rainActivityUpdater: rainUpdater,
            notificationScheduler: scheduler,
            fetchMetrics: metrics,
            defaults: mockDefaults
        )

        let weather = MockWeatherRepository.makeGhaziabadWeather()
        await coordinator.handleSuccessfulRefresh(weather)

        // Spotlight was skipped
        #expect(indexer.indexedWeathers.isEmpty)

        // All other side effects ran
        #expect(writer.savedSnapshots.count == 1)
        #expect(writer.reloadCount == 1)
        #expect(rainUpdater.updateCalls.count == 1)
        #expect(scheduler.handleRefreshCalls.count == 1)
        #expect(metrics.recordFetchCount == 1)
    }
}
