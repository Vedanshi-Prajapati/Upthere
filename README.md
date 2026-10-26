# UpThere

[![CI](https://github.com/Vedanshi-Prajapati/Upthere/actions/workflows/ci.yml/badge.svg)](https://github.com/Vedanshi-Prajapati/Upthere/actions/workflows/ci.yml)
[![Swift](https://img.shields.io/badge/Swift-6.0-orange?logo=swift&logoColor=white)](https://swift.org)
[![Platform](https://img.shields.io/badge/iOS-26.0%2B-blue?logo=apple&logoColor=white)](https://developer.apple.com/ios/)
[![UI Framework](https://img.shields.io/badge/SwiftUI-purple?logo=swift&logoColor=white)](https://developer.apple.com/xcode/swiftui/)

An iOS weather application built with SwiftUI, Apple WeatherKit, and deterministic forecast intelligence algorithms.

<p align="center">
  <img src="docs/screenshots/home-dark.png" alt="UpThere Home Screen" width="360">
</p>

### Interface & Adaptability

| Light Mode | Dark Mode | Dynamic Type (Small) | Dynamic Type (Large) | WidgetKit |
| :---: | :---: | :---: | :---: | :---: |
| <img src="docs/screenshots/home-light.png" width="180" alt="Light Mode"> | <img src="docs/screenshots/home-dark.png" width="180" alt="Dark Mode"> | <img src="docs/screenshots/home-small.png" width="180" alt="Dynamic Type - Small Text"> | <img src="docs/screenshots/home-large.png" width="180" alt="Dynamic Type - Large Text"> | <img src="docs/screenshots/widget.png" width="180" alt="WidgetKit Medium Widget"> |

---

## Overview

Most weather applications present raw meteorological metrics—barometric pressures, percentages, and millibar measurements—leaving the user to interpret what those numbers mean for their daily schedule. UpThere bridges this gap by transforming hourly forecast telemetry into clear, actionable context: identifying exact precipitation windows, assessing outdoor activity suitability, tracking temperature swings, and flagging peak UV periods. Designed natively for iOS 26, the app pairs this analytical engine with dynamic atmospheric sky rendering, custom vector illustrations, and platform integrations across widgets, Control Center, Siri Shortcuts, and Spotlight.

> [!NOTE]
> **iOS 26+ Deployment Target as a Deliberate Choice**
> UpThere exclusively targets iOS 26.0+ as a deliberate design and architectural decision. By eschewing backward-compatibility branching and runtime OS version checks (`if #available(...)`), the codebase fully leverages modern Swift 6 concurrency (`SWIFT_STRICT_CONCURRENCY = complete`), native `@Observable` state observation, modern SwiftUI Liquid Glass materials, standard MapKit address search representations, WidgetKit interactive timeline extensions, and App Intents without legacy compatibility shims.

---

## Architecture

The project follows a clean, modular layer architecture separating Presentation, Domain business logic, Data repositories, and Platform integration.

```mermaid
graph TD
    subgraph Presentation ["Presentation Layer (SwiftUI & ViewModels)"]
        UI[SwiftUI Views: HomeView, ForecastView, InsightsView, SettingsView]
        VM[HomeViewModel, CitySearchViewModel, SettingsViewModel @Observable]
        UI -->|Binds to state| VM
    end

    subgraph Domain ["Domain Layer (Business Logic & Entities)"]
        UC[GetWeatherUseCase]
        RC[WeatherRefreshCoordinator @MainActor]
        IE[InsightEngine & RainActivityStateCalculator]
        DM[Domain Models: Weather, HourlyWeather, LocationStatus]
        VM -->|Executes| UC
        VM -->|Delegates refresh side effects| RC
        VM -->|Evaluates forecast metrics| IE
    end

    subgraph Data ["Data Layer (Repositories & Persistence)"]
        RP[WeatherRepository Protocol]
        WR[WeatherKitWeatherRepository]
        MR[MockWeatherRepository]
        LS[LocationService & LocationStore]
        LM[SavedLocationsManager]
        CM[WeatherCacheManager]
        UC -->|Queries interface| RP
        RP -->|Production| WR
        RP -->|Offline / Testing| MR
        WR -->|Apple API| WK[WeatherService / CoreLocation]
        WR -->|Caches to| CM
        LM -->|Persists to| LS
    end

    subgraph Platform ["Platform & Extensions Layer"]
        WID[WidgetKit Target & UpthereWidgets]
        WSS[WidgetSnapshotStore]
        SI[SpotlightService & CSSearchableItem]
        AI[App Intents: CheckWeatherIntent, TrackRainIntent]
        AG[AppGroup Shared Storage]
        RC -->|Writes snapshot| WSS
        RC -->|Indexes search| SI
        WID -->|Reads snapshot| WSS
        AI -->|Invokes loader| WR
        WSS -->|Shares via| AG
    end
```

### Verified Test Coverage by Layer

All **120 tests** across **16 test suites** pass deterministically using Apple's Swift Testing framework (`@Suite`, `@Test`, `#expect`):

| Layer / Feature Suite | Test Count | Key Areas Covered |
| :--- | :---: | :--- |
| **HomeViewModel Tests** | **21** | Launch states, permission revoking, offline fallbacks, city selection, stale response dropping, rapid debouncing, refresh failure retention, geocoding timeouts & async resolution. |
| **Settings Tests** | **14** | `ToggleSevereAlertsIntent`, `SettingsViewModel` settings keys & bundle version, Spotlight toggle, `SavedLocationsManager` persistence, current location pinning, filtered reordering, duplicate detection, `FileLocationStore` migration, and `AppGroup` migration. |
| **WeatherMapping Tests** | **10** | Decoding failures, partial forecasts, condition codes, temperature formatting/conversions, forecast midnight timestamps, expired alerts, extended hourly metrics, rain window formatting, dynamic unit preferences view formatting. |
| **Rain Activity State Tests** | **10** | Rain onset/cessation/intensity calculations, sliding windows, Live Activity ContentState mapping. |
| **IntentWeatherLoader Tests** | **9** | Intent location resolution (`nil`, `current`, custom city), network fetch with dual-key cache fallback, `WeatherUnavailableError`, dialog builder string formatting. |
| **WidgetSnapshot Tests** | **8** | Snapshot JSON round-trip, weather-to-snapshot mapping, fresh/stale/empty widget entries, timeline provider fresh fetch, stale fallback, and missing snapshot states. |
| **InsightEngine Tests** | **6** | Weather patterns (rain window, best outdoor window, temperature trends, peak UV, cloud changes). |
| **Notification Tests** | **6** | Severe weather deduplication, rain alert scheduling & rescheduling, cancellation on weather clear, toggle gating, permission request triggers, refresh-triggered rain scheduling. |
| **WeatherRefreshCoordinator Tests** | **6** | Single-run side-effects coordinator, widget timeline reloading, Spotlight indexing bypass, error tolerance. |
| **Cache Tests** | **5** | Cache key city isolation, `CheckWeatherIntent` cached fallback & unavailable error, `TrackRainIntent` cached fallback & unavailable error. |
| **LocationService Tests** | **5** | Timeout within 4s, reverse-geocoding immutability, request generation counter. |
| **LocationStatus Tests** | **5** | Banner derivation for `.denied`, `.timedOut`, `.savedCity`, `.live`, banner actions. |
| **City Search Tests** | **5** | Typing debounce, request cancellation, duplicate regional filtering. |
| **WCAG AA Contrast Verification** | **5** | Algorithmic luminance and WCAG AA / AAA contrast validation on dynamic sky canvases. |
| **Sky Background Tests** | **3** | Dynamic sky scene classification, diurnal particle systems. |
| **Spotlight Tests** | **2** | `SpotlightService` identifier resolution, `LocationEntityQuery` entity fetching. |
| **Total** | **120** | **100% Passing** |

---

## Key Features

### 1. Weather Experience
- **Atmospheric Sky Engine**: Multi-layer background canvas reflecting real-time weather conditions, ambient lighting, and diurnal shifts with restrained particle motion for rain, snow, fog, and storms.
- **Animated Vector Illustrations**: Custom SwiftUI path-based vector illustrations (`WeatherIllustrationView`) providing fluid visual feedback without static raster assets.
- **Interactive Temperature Scrubbing**: Canvas-rendered hourly temperature curve (`TemperatureLineChart`) with monotonic cubic smoothing and touch scrubbing to inspect discrete hourly data points.
- **Liquid Glass & Materials**: Cohesive visual hierarchy utilizing SwiftUI's native `.glassEffect` styling on navigation bars, controls, and tab bars alongside system materials on content cards.

### 2. Forecast Intelligence (`InsightEngine`)
- **Precipitation Windows**: Identifies rain onset, cessation, peak probability hour, and accumulated volume from hourly data slices.
- **Outdoor Suitability Scoring**: Multi-factor heuristic evaluating temperature comfort bands (18–25°C), precipitation penalties, wind velocity, and UV exposure to score the best time for outdoor activities.
- **Diurnal Temperature Trends**: Identifies daily highs, lows, and rapid swings between sequential hours.
- **Extended Forecasts**: 24-hour continuous timeline and 10-day outlook with high/low range bars and precipitation probabilities.

### 3. Location and Personalization
- **City Search**: Fast, debounced city search powered by Apple MapKit (`MKLocalSearch`) utilizing iOS 26 location and address representations.
- **Multi-City Management**: Saved locations list with reordering, swipe deletion, and automatic pinning of the device's current location.
- **Proximity Deduplication**: Enforces a 5 km minimum threshold (`CLLocation.distance`) to prevent duplicate city entries within the same metropolitan area.
- **Observable Unit Preferences**: Reactive `@Observable` unit settings (`UnitPreferences`) for temperature (°C / °F), wind speed (km/h / mph / m/s / kn), and precipitation (mm / in) injected through the SwiftUI Environment.
- **Graceful Fallbacks**: Deterministic fallback to coordinate presets (Ghaziabad) when location permissions are denied or unavailable.

### 4. Native iOS Integrations
- **WidgetKit**: Home Screen and Lock Screen widgets supporting `.systemSmall`, `.systemMedium`, `.systemLarge`, `.accessoryCircular`, `.accessoryRectangular`, and `.accessoryInline` families.
- **Control Center**: Quick weather launcher control and severe weather alert toggle control (`ControlWidget`).
- **App Shortcuts & Siri**: Siri shortcuts (`UpthereShortcuts`) for checking current weather (`CheckWeatherIntent`), opening locations (`OpenLocationIntent`), toggling severe alerts (`ToggleSevereAlertsIntent`), and tracking rain (`TrackRainIntent`).
- **CoreSpotlight Indexing**: Automatic indexing of current weather conditions and saved cities into iOS system search via `CSSearchableItem`, with user preference toggle and index management in Settings.

---

## Technical Highlights

### Deterministic Insight Engine (`InsightEngine`)
Rather than relying on server-side processing or machine learning models, forecast insights are computed entirely on-device using pure Swift algorithms. The `InsightEngine` inspects `[HourlyWeather]` slices across six deterministic functions:
- `rainWindow`: Scans hourly probabilities to compute start, peak, and end timestamps along with total precipitation volume.
- `bestOutdoorWindow`: Implements a scoring function penalizing rain probability (up to -80 pts), deviation from optimal comfort temperatures (18–25°C), high winds (>20 km/h), and extreme UV (>7) across sliding 3-hour windows.
- `temperatureTrend`: Calculates daily swings and inflection point timestamps.
- `strongestWind`: Evaluates sustained speeds against peak gust windows.
- `peakUV`: Pinpoints midday solar intensity boundaries.
- `cloudChange`: Measures delta rates across cloud coverage arrays to detect incoming fronts or clearing skies.

### Repository Abstraction & Testing Architecture
Data access is isolated behind the `WeatherRepository` protocol:
- **`WeatherKitWeatherRepository`**: Wraps Apple's `WeatherService`, handles geocoding coordinate resolution, maps system errors into strongly-typed `WeatherServiceError` cases, and caches responses.
- **`MockWeatherRepository`**: Provides fully deterministic mock fixtures and simulated network latency for testing and simulator development without active Apple Developer certificates.

### State Management & Concurrency
- **Observation Framework**: ViewModels utilize Swift's `@Observable` macro for property-level view invalidation and reduced view re-renders compared to `ObservableObject`.
- **Actor Isolation**: All UI-facing view models and container factories are isolated to `@MainActor`.
- **AsyncStream Location Updates**: `LocationService` bridges CoreLocation delegate callbacks into an asynchronous sequence (`AsyncStream<CLLocation>`), allowing view models to reactively consume location changes without tight delegate coupling.
- **Request Cancellation**: In-flight fetch tasks are managed via structured `Task` references, automatically cancelling superseded requests on city change or rapid refresh.

### Cache Strategy & Storage
- **`WeatherCacheManager`**: Stores timestamped JSON payloads in `UserDefaults` using sanitized city and coordinate keys. Cache records maintain freshness for 30 minutes and allow stale reads up to 24 hours to support offline launches.
- **`FileLocationStore`**: Stores saved location metadata as JSON directly in `Application Support/Upthere/`, ensuring persistence independent of cache flushes, with an automated migration routine for legacy `UserDefaults` stores.

---

## Quick Start

### Prerequisites
- macOS 15.0+
- Xcode 26.0+
- iOS 26.0+ Simulator or physical device

### Building the Project

1. **Clone the repository:**
   ```bash
   git clone https://github.com/Vedanshi-Prajapati/Upthere.git
   cd Upthere
   ```

2. **Open the project in Xcode:**
   ```bash
   open Upthere.xcodeproj
   ```

3. **Select Scheme and Destination:**
   - Select the `Upthere` scheme.
   - Choose an iOS 26.0+ Simulator (such as `iPhone 16`).

4. **Run:**
   - Press `Cmd + R` to build and launch.

### Live Data vs. Mock Development
- **Live WeatherKit Data**: Apple WeatherKit requires an active Apple Developer Program account, an explicit App ID with the WeatherKit capability enabled, and proper code signing. The entitlement is defined in `Upthere/Upthere.entitlements`.
- **Offline / Simulator Testing**: To run the project without an active Apple Developer team or certificate, inject `MockWeatherRepository` into `AppContainer` (`Upthere/App/AppContainer.swift`), which provides full synthetic hourly and 10-day forecasts without external network calls.

### Building & Testing via Terminal

#### Building
To build from the terminal without binding to a specific simulator installed on your machine:

```bash
xcodebuild build \
  -scheme Upthere \
  -destination 'generic/platform=iOS Simulator'
```

#### Running Tests
Executing tests requires a concrete simulator device. Run the test suite on any booted simulator:

```bash
xcodebuild test \
  -scheme Upthere \
  -destination "platform=iOS Simulator,id=booted" \
  -only-testing:UpthereTests
```

Or target the first available iPhone simulator dynamically without hardcoding a device name:

```bash
DEVICE_ID=$(xcrun simctl list devices available | grep -m 1 "iPhone" | grep -E -o '[0-9A-F]{8}-([0-9A-F]{4}-){3}[0-9A-F]{12}')
xcodebuild test \
  -scheme Upthere \
  -destination "id=$DEVICE_ID" \
  -only-testing:UpthereTests
```

> **Note:** To list all installed simulator runtimes and devices on your machine, run `xcrun simctl list devices available`.

---

## Limitations

- **Notification Scheduling**: Weather notifications (rain onset alerts and severe weather alerts) are scheduled and rescheduled only during active app refresh cycles (e.g. user pull-to-refresh or foreground launch). The app does not currently implement background app refresh (`BGAppRefreshTask`) to periodically query WeatherKit while suspended.
- **WeatherKit Entitlement Requirement**: Fetching real-time meteorological data requires a paid Apple Developer account and signed bundle provisioning with the `com.apple.developer.weatherkit` entitlement.
- **Forecast Horizon**: The application displays up to 24 hourly intervals and a 10-day daily forecast based on the maximum forecast windows provided by Apple's WeatherService.
- **Geocoding Availability**: City name resolution, MapKit city searches, and reverse geocoding rely on Apple network services (`MKLocalSearch` and `CLGeocoder`).

---

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
