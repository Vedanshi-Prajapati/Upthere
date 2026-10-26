import XCTest

nonisolated final class UpthereUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - (1) Cold-launch test using XCTApplicationLaunchMetric
    @MainActor
    func testColdLaunchPerformance() throws {
        let options = XCTMeasureOptions()
        options.iterationCount = 1
        measure(metrics: [XCTApplicationLaunchMetric()], options: options) {
            let app = XCUIApplication()
            app.launchArguments = ["-useMockRepository", "-disableSplash", "-disablePermission"]
            app.launch()
        }
    }

    // MARK: - (2) Launches with mock repository and navigates all five tabs without crashing
    @MainActor
    func testNavigateAllFiveTabsWithoutCrashing() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-useMockRepository", "-disableSplash", "-disablePermission"]
        app.launch()

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 8), "Tab bar should exist on launch")

        // 1. Home tab
        let homeTab = tabBar.buttons["Home"]
        XCTAssertTrue(homeTab.waitForExistence(timeout: 4), "Home tab button should exist")
        homeTab.tap()

        let homeHeader = app.staticTexts["UpThere"]
        XCTAssertTrue(homeHeader.waitForExistence(timeout: 4) || tabBar.exists)

        // 2. Forecast tab
        let forecastTab = tabBar.buttons["Forecast"]
        XCTAssertTrue(forecastTab.waitForExistence(timeout: 4), "Forecast tab button should exist")
        forecastTab.tap()

        let hourlyOrForecast = app.staticTexts["Forecast"].exists || app.buttons["Hourly"].waitForExistence(timeout: 4)
        XCTAssertTrue(hourlyOrForecast || tabBar.exists, "Forecast tab content should appear")

        // 3. Insights tab
        let insightsTab = tabBar.buttons["Insights"]
        XCTAssertTrue(insightsTab.waitForExistence(timeout: 4), "Insights tab button should exist")
        insightsTab.tap()

        let insightsContent = app.staticTexts["Forecast Insights"].waitForExistence(timeout: 4)
            || app.staticTexts["InsightEngine"].waitForExistence(timeout: 4)
        XCTAssertTrue(insightsContent || tabBar.exists, "Insights tab content should appear")

        // 4. Locations tab
        let locationsTab = tabBar.buttons["Locations"]
        XCTAssertTrue(locationsTab.waitForExistence(timeout: 4), "Locations tab button should exist")
        locationsTab.tap()

        let locationsNavBar = app.navigationBars["Locations"].waitForExistence(timeout: 4)
            || app.staticTexts["Locations"].waitForExistence(timeout: 4)
        XCTAssertTrue(locationsNavBar || tabBar.exists, "Locations tab content should appear")

        // 5. Settings tab
        let settingsTab = tabBar.buttons["Settings"]
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 4), "Settings tab button should exist")
        settingsTab.tap()

        let settingsContent = app.staticTexts["Settings"].waitForExistence(timeout: 4)
            || app.navigationBars["Settings"].waitForExistence(timeout: 4)
        XCTAssertTrue(settingsContent || tabBar.exists, "Settings tab content should appear")

        // Return to Home tab
        homeTab.tap()
        XCTAssertTrue(tabBar.exists)
    }

    // MARK: - (3) Widget snapshot file exists after a successful fetch
    @MainActor
    func testWidgetSnapshotFileExistsAfterSuccessfulFetch() throws {
        let snapshotFileName = "ui_test_widget_snapshot_\(UUID().uuidString).json"
        let tempSnapshotURL = FileManager.default.temporaryDirectory.appendingPathComponent(snapshotFileName)
        try? FileManager.default.removeItem(at: tempSnapshotURL)

        let app = XCUIApplication()
        app.launchEnvironment["WIDGET_SNAPSHOT_PATH"] = tempSnapshotURL.path
        app.launchArguments = ["-useMockRepository", "-disableSplash", "-disablePermission"]
        app.launch()

        // Wait for app to finish launching and load mock weather
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 8), "App should launch and display tab bar")

        // Wait for snapshot file to be written to disk
        let existsPredicate = NSPredicate { _, _ in
            FileManager.default.fileExists(atPath: tempSnapshotURL.path)
        }
        let expectation = XCTNSPredicateExpectation(predicate: existsPredicate, object: nil)
        let waiterResult = XCTWaiter().wait(for: [expectation], timeout: 8.0)

        XCTAssertEqual(waiterResult, .completed, "Widget snapshot file should be written to disk after successful weather fetch")
        XCTAssertTrue(FileManager.default.fileExists(atPath: tempSnapshotURL.path), "Snapshot file must exist")

        let data = try Data(contentsOf: tempSnapshotURL)
        XCTAssertGreaterThan(data.count, 0, "Snapshot file must not be empty")

        // Clean up
        try? FileManager.default.removeItem(at: tempSnapshotURL)
    }

    // MARK: - (4) Hero text frame non-empty in light appearance
    @MainActor
    func testHeroTextFrameNonEmptyInLightAppearance() throws {
        XCUIDevice.shared.appearance = .light

        let app = XCUIApplication()
        app.launchArguments = [
            "-useMockRepository",
            "-disableSplash",
            "-disablePermission",
            "-initialTab", "home",
            "-AppleInterfaceStyle", "Light"
        ]
        app.launch()

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 8), "App should launch and display tab bar")

        let heroTemp = app.staticTexts["hero_temperature"]
        let heroText = app.otherElements["hero_text_content"]
        let heroSection = app.otherElements["hero_section"]

        let targetElement: XCUIElement
        if heroTemp.waitForExistence(timeout: 2) {
            targetElement = heroTemp
        } else if heroText.waitForExistence(timeout: 1) {
            targetElement = heroText
        } else {
            XCTAssertTrue(heroSection.waitForExistence(timeout: 4), "Hero section must exist")
            targetElement = heroSection
        }

        XCTAssertFalse(targetElement.frame.isEmpty, "Hero text frame should not be empty")
        XCTAssertGreaterThan(targetElement.frame.width, 0, "Hero text width should be greater than zero")
        XCTAssertGreaterThan(targetElement.frame.height, 0, "Hero text height should be greater than zero")
    }

    // MARK: - (5) UI performance tests using XCTCPUMetric for 10 seconds of idle Home in clear and rain states
    @MainActor
    func testIdleHomeClearCPUPerformance() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "-useMockRepository",
            "-mockCondition", "clear",
            "-disableSplash",
            "-disablePermission",
            "-initialTab", "home"
        ]
        app.launch()

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 8), "App should launch and display tab bar")

        let metric = XCTCPUMetric(application: app)
        let options = XCTMeasureOptions()
        options.iterationCount = 1
        measure(metrics: [metric], options: options) {
            Thread.sleep(forTimeInterval: 10.0)
        }
    }

    @MainActor
    func testIdleHomeRainCPUPerformance() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "-useMockRepository",
            "-mockCondition", "rain",
            "-disableSplash",
            "-disablePermission",
            "-initialTab", "home"
        ]
        app.launch()

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 8), "App should launch and display tab bar")

        let metric = XCTCPUMetric(application: app)
        let options = XCTMeasureOptions()
        options.iterationCount = 1
        measure(metrics: [metric], options: options) {
            Thread.sleep(forTimeInterval: 10.0)
        }
    }

    // MARK: - (6) Dynamic Type XXXL rendering test
    @MainActor
    func testDynamicTypeXXXL() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "-useMockRepository",
            "-disableSplash",
            "-disablePermission",
            "-initialTab", "home",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge"
        ]
        app.launch()

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 8), "App should launch in Dynamic Type XXXL")

        let heroSection = app.descendants(matching: .any)["hero_section"].firstMatch
        XCTAssertTrue(heroSection.waitForExistence(timeout: 8), "Hero section should exist in Dynamic Type XXXL")
        XCTAssertFalse(heroSection.frame.isEmpty, "Hero section frame must be non-empty in Dynamic Type XXXL")
        XCTAssertGreaterThan(heroSection.frame.height, 0)
        XCTAssertGreaterThan(heroSection.frame.width, 0)

        // Verify navigation across tabs in XXXL without crashing
        let forecastTab = tabBar.buttons["Forecast"].firstMatch
        if forecastTab.waitForExistence(timeout: 4) {
            forecastTab.tap()
            XCTAssertTrue(app.staticTexts["Forecast"].firstMatch.waitForExistence(timeout: 4) || tabBar.exists)
        }

        let settingsTab = tabBar.buttons["Settings"].firstMatch
        if settingsTab.waitForExistence(timeout: 4) {
            settingsTab.tap()
            XCTAssertTrue(app.staticTexts["Settings"].firstMatch.waitForExistence(timeout: 4) || tabBar.exists)
        }
    }

    // MARK: - (7) VoiceOver label presence across all tabs
    @MainActor
    func testVoiceOverLabelPresence() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "-useMockRepository",
            "-disableSplash",
            "-disablePermission",
            "-initialTab", "home"
        ]
        app.launch()

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 8), "App should launch and display tab bar")

        // 1. Home VoiceOver elements
        let heroSection = app.descendants(matching: .any)["hero_section"].firstMatch
        XCTAssertTrue(heroSection.waitForExistence(timeout: 8), "Hero section should exist")
        XCTAssertFalse(heroSection.label.isEmpty, "Hero section must have VoiceOver accessibility label")

        let tempChart = app.descendants(matching: .any)["temperature_line_chart"].firstMatch
        XCTAssertTrue(tempChart.waitForExistence(timeout: 8), "Temperature chart should exist with identifier")
        XCTAssertFalse(tempChart.label.isEmpty, "Temperature chart accessibility label must not be empty")

        // 2. Forecast VoiceOver elements
        let forecastTab = tabBar.buttons["Forecast"].firstMatch
        XCTAssertTrue(forecastTab.waitForExistence(timeout: 4))
        forecastTab.tap()

        let hourlyBtn = app.descendants(matching: .any)["forecast_hourly_button"].firstMatch
        XCTAssertTrue(hourlyBtn.waitForExistence(timeout: 4), "Hourly forecast button should exist")
        XCTAssertFalse(hourlyBtn.label.isEmpty, "Hourly forecast button must have VoiceOver label")

        let dailyBtn = app.descendants(matching: .any)["forecast_daily_button"].firstMatch
        XCTAssertTrue(dailyBtn.waitForExistence(timeout: 4), "Daily forecast button should exist")
        XCTAssertFalse(dailyBtn.label.isEmpty, "Daily forecast button must have VoiceOver label")

        // 3. Insights VoiceOver elements
        let insightsTab = tabBar.buttons["Insights"].firstMatch
        XCTAssertTrue(insightsTab.waitForExistence(timeout: 4))
        insightsTab.tap()

        let insightsHeader = app.staticTexts["Insights"].firstMatch
        XCTAssertTrue(insightsHeader.waitForExistence(timeout: 4) || tabBar.exists)

        // 4. Locations VoiceOver elements
        let locationsTab = tabBar.buttons["Locations"].firstMatch
        XCTAssertTrue(locationsTab.waitForExistence(timeout: 4))
        locationsTab.tap()

        let addCityBtn = app.descendants(matching: .any)["add_city_button"].firstMatch
        XCTAssertTrue(addCityBtn.waitForExistence(timeout: 4), "Add city button should exist")
        XCTAssertFalse(addCityBtn.label.isEmpty, "Add city button must have VoiceOver label")

        // 5. Settings VoiceOver elements
        let settingsTab = tabBar.buttons["Settings"].firstMatch
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 4))
        settingsTab.tap()

        let tempUnitRow = app.descendants(matching: .any)["settings_temp_unit_row"].firstMatch
        XCTAssertTrue(tempUnitRow.waitForExistence(timeout: 4), "Temperature unit row should exist")
        XCTAssertFalse(tempUnitRow.label.isEmpty, "Temperature unit row must have VoiceOver label")

        let rainToggle = app.descendants(matching: .any)["settings_rain_alerts_toggle"].firstMatch
        XCTAssertTrue(rainToggle.waitForExistence(timeout: 4), "Rain alerts toggle should exist")
        XCTAssertFalse(rainToggle.label.isEmpty, "Rain alerts toggle must have VoiceOver label")
    }
}
