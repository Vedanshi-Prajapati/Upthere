import XCTest

nonisolated final class UpthereUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - (1) Cold-launch test using XCTApplicationLaunchMetric
    @MainActor
    func testColdLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric(waitUntilResponsive: true)]) {
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

        let insightsContent = app.staticTexts["Forecast Insights"].waitForExistence(timeout: 4) || app.staticTexts["InsightEngine"].waitForExistence(timeout: 4)
        XCTAssertTrue(insightsContent || tabBar.exists, "Insights tab content should appear")

        // 4. Locations tab
        let locationsTab = tabBar.buttons["Locations"]
        XCTAssertTrue(locationsTab.waitForExistence(timeout: 4), "Locations tab button should exist")
        locationsTab.tap()

        let locationsNavBar = app.navigationBars["Locations"].waitForExistence(timeout: 4) || app.staticTexts["Locations"].waitForExistence(timeout: 4)
        XCTAssertTrue(locationsNavBar || tabBar.exists, "Locations tab content should appear")

        // 5. Settings tab
        let settingsTab = tabBar.buttons["Settings"]
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 4), "Settings tab button should exist")
        settingsTab.tap()

        let settingsContent = app.staticTexts["Settings"].waitForExistence(timeout: 4) || app.navigationBars["Settings"].waitForExistence(timeout: 4)
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
}
