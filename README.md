# UpThere ⛅

[![Swift](https://img.shields.io/badge/Swift-5.10%20%7C%206.0-orange?logo=swift&logoColor=white)](https://swift.org)
[![Platform](https://img.shields.io/badge/Platform-iOS%2018%2B-blue?logo=apple&logoColor=white)](https://developer.apple.com/ios/)
[![UI Framework](https://img.shields.io/badge/UI-SwiftUI-red?logo=swift&logoColor=white)](https://developer.apple.com/xcode/swiftui/)
[![WeatherKit](https://img.shields.io/badge/Powered%20By-Apple%20WeatherKit-blueviolet)](https://developer.apple.com/weatherkit/)
[![Architecture](https://img.shields.io/badge/Architecture-Clean%20%2B%20MVVM-green)](https://en.wikipedia.org/wiki/Clean_architecture)
[![License](https://img.shields.io/badge/License-MIT-lightgrey.svg)](LICENSE)

> **Atmospheric Intelligence for iOS.**  
> A weather experience crafted in pure SwiftUI, combining Apple WeatherKit, photorealistic atmospheric rendering, custom animated vector illustrations, deterministic insight analytics, Lock Screen / Home Screen widgets, Control Center controls, and system-wide Spotlight integration.

---

## 🌟 Overview

**UpThere** reimagines how weather forecasts are presented. Rather than overwhelming users with raw numbers and disconnected charts, UpThere translates meteorological telemetry into **actionable human insights**—answering what the forecast actually means for your day.

From pinpointing the exact dry window for your afternoon run, to tracking sudden barometric shifts and peak UV windows, UpThere pairs high-precision Apple WeatherKit data with an ambient, glassmorphic design that adapts naturally to time and weather conditions.

---

## ✨ Features

### 🎨 Atmospheric Visual Engine & Dynamic Motion
- **Photorealistic Sky Canvas**: Ambient sky gradients and particle systems tuned for rain, thunder, snow, fog, overcast, and clear day/night conditions.
- **Pure Vector Animated Illustrations**: Lightweight, dependency-free SwiftUI vector animations (`WeatherIllustrationView`) that breathe life into weather conditions without static raster assets.
- **Glassmorphic Material Styling**: Translucent background blurs, ambient contrast badges, and cohesive typography conforming to Apple's Human Interface Guidelines.

### 💡 Deterministic InsightEngine
A pure Swift domain engine (`InsightEngine`) analyzes 24+ hours of hourly telemetry to generate actionable context:
- **🌧️ Rain Window**: Detects precipitation onset, cessation, peak probability hour, and accumulated rainfall.
- **🌡️ Temperature Trends**: Identifies daily diurnal swings, inflection points, and notable temperature dips.
- **💨 Wind & Gust Timeline**: Predicts peak gusts and advises on high-wind windows.
- **🏃 Best Outdoor Window**: Multi-factor heuristic scoring (balancing comfortable temperature bands 18–25°C, precipitation penalties, wind velocity, and UV index) to identify ideal times for outdoor activities.
- **☀️ Peak UV Windows**: Flags peak solar radiation intervals to promote sun safety.
- **☁️ Cloud Cover Shifts**: Tracks clearing patterns and cloud ceiling shifts across the day.

### 📈 Interactive Charts & Metrics
- **Interactive Temperature Curve**: Custom SwiftUI canvas chart (`TemperatureLineChart`) with hourly temperature points, gradient fills, and touch scrubbing.
- **Hourly & 10-Day Extended Forecasts**: High/low temperature bars, condition badges, and precipitation probability timelines.
- **Atmospheric Metric Tiles**: Comprehensive telemetry cards for Feels Like, Humidity, Wind Speed, UV Index, Visibility, Pressure, and Sunrise/Sunset times.

### 📍 Multi-Location Management
- **Intelligent Location Services**: Automated reverse geocoding with Apple CoreLocation and AsyncStream tracking.
- **Persistent Storage**: Robust file-based JSON persistence (`LocationStore`) in the Application Support directory with automatic migration.
- **5km Deduplication**: Smart proximity detection preventing redundant saves of the same metropolitan areas.
- **Offline & Graceful Fallback**: Deterministic fallback mechanism (Ghaziabad anchor) ensuring uninterrupted functionality when permissions are denied or network is unavailable.

### 📲 Deep iOS Platform Integrations
- **WidgetKit (Home & Lock Screen)**:
  - Rich widget family coverage: `.systemSmall`, `.systemMedium`, `.systemLarge`, `.accessoryCircular`, `.accessoryRectangular`, and `.accessoryInline`.
  - Hourly forecast ribbons and precipitation summaries directly on your Home Screen.
- **Control Center Controls (iOS 18+)**:
  - Quick launch button (`UpthereQuickWeatherControl`).
  - Interactive Severe Alert toggle (`UpthereAlertsControl`).
- **App Intents & Siri Shortcuts**:
  - Native shortcuts via `AppShortcutsProvider`: *"Check Weather in UpThere"*, *"Open London in UpThere"*, and severe alerts toggle.
- **CoreSpotlight Search**:
  - Automatic indexing of current conditions and saved cities (`SpotlightService`), allowing users to search weather directly from iOS Spotlight.

### ⚙️ User Customization & Accessibility
- **Units**: Full support for Metric (°C, km/h, mm) and Imperial (°F, mph, in) units.
- **Appearance & Typography**: Dynamic Type scaling and dedicated Dark, Light, or System appearance overrides.
- **VoiceOver & Accessibility**: Clear accessibility labels, high-contrast text modes, and semantic layout structuring.

---

## 🏛️ Architecture & Project Structure

UpThere is designed around **Clean Architecture**, **SOLID principles**, and **Unidirectional Data Flow**:

```
Upthere/
├── App/                            # Application entry and dependency container
│   ├── AppContainer.swift          # MainActor dependency injection container
│   ├── AppTheme.swift              # Design system tokens, materials, and colors
│   └── WeatherFormatter.swift      # Localized formatting for temperatures & units
│
├── Domain/                         # Pure business logic (framework agnostic)
│   ├── Models/                     # Core entities (Weather, HourlyWeather, etc.)
│   ├── Repositories/               # Repository interfaces (WeatherRepository)
│   ├── UseCases/                   # Use case contracts and implementations
│   └── InsightEngine.swift         # Deterministic weather insight algorithms
│
├── Data/                           # Data access and platform adapters
│   ├── Repositories/               # WeatherKit and Mock repository implementations
│   └── Services/                   # CoreLocation, LocationStore, and WeatherCache
│
├── Features/                       # UI Feature modules (SwiftUI + @Observable)
│   ├── Home/                       # Main weather screen & interactive charts
│   ├── Forecast/                   # 10-day extended outlook
│   ├── Insights/                   # InsightEngine breakdown cards & visual charts
│   ├── Locations/                  # Multi-city management, search, and ordering
│   ├── Settings/                   # Units, appearance, notifications, and about
│   └── Shared/                     # Reusable components, backgrounds, and animations
│
├── Platform/                       # Native system integrations
│   ├── Intents/                    # App Intents and Siri AppShortcutsProvider
│   └── Spotlight/                  # CoreSpotlight indexing service
│
├── UpthereWidgets/                 # WidgetKit extension & Control Center controls
└── UpthereTests/                   # Swift Testing suite (@Suite, @Test)
```

---

## 🚀 Getting Started

### Prerequisites
- **macOS Sonoma 14.5+** or **macOS Sequoia 15.0+**
- **Xcode 16.0+**
- **iOS 17.6+ / iOS 18.0+** simulator or physical device
- *(Optional)* Apple Developer Account with WeatherKit capability enabled (for live WeatherKit telemetry)

### Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/Vedanshi-Prajapati/Upthere.git
   cd Upthere
   ```

2. **Open in Xcode:**
   ```bash
   open Upthere.xcodeproj
   ```

3. **Select Scheme & Device:**
   - Select the `Upthere` scheme.
   - Choose an iOS 18.0+ Simulator (e.g., iPhone 16 Pro) or your connected physical device.

4. **Build and Run:**
   - Press `Cmd + R` or click the **Play** button in Xcode.

> [!TIP]
> **No Developer Account?**  
> The project includes a full-featured `MockWeatherRepository` that simulates realistic diurnal curves, rain windows, gusts, and multi-day forecasts. You can preview all views, widgets, and charts in the simulator without setting up WeatherKit certificates!

---

## 🧪 Testing

UpThere utilizes Apple's modern **Swift Testing** framework (`@Suite`, `@Test`, `#expect`) to guarantee domain correctness and UI state resilience:

- **InsightEngine Edge Cases**: Validates rain window bounds, dead calm handling, extreme heat/cold swings, UV peak detection, and cloud transitions.
- **Location Lifecycle Tests**: Verifies permission-grant flows, denied fallbacks, service shutdowns, and isolated test storage suites.
- **Deduplication Tests**: Asserts that cities within a 5km radius are identified as duplicates during search.

### Running Tests via Xcode
Press `Cmd + U` to execute the full test suite.

### Running Tests via Terminal
```bash
xcodebuild test \
  -scheme Upthere \
  -destination "platform=iOS Simulator,name=iPhone 16 Pro" \
  -only-testing:UpthereTests
```

---

## 🛡️ License

UpThere is open-source software licensed under the **[MIT License](LICENSE)**.

---

<p align="center">
  Crafted with care using SwiftUI and Swift.
</p>
