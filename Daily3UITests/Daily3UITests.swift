//
//  Daily3UITests.swift
//  Daily3UITests
//
//  Created by Ayse Nur AYAYDIN on 7.10.2026.
//

import XCTest

final class Daily3UITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testTodayScreenShowsThreePriorities() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.navigationBars["Daily 3"].exists)
        XCTAssertTrue(app.textFields["Priority 1"].exists)
        XCTAssertTrue(app.textFields["Priority 2"].exists)
        XCTAssertTrue(app.textFields["Priority 3"].exists)
    }

    @MainActor
    func testCalendarTabShowsCalendarScreen() throws {
        let app = XCUIApplication()
        app.launch()

        app.tabBars.buttons["Calendar"].tap()

        XCTAssertTrue(app.navigationBars["Calendar"].exists)
    }

    @MainActor
    func testStatisticsShowsSummaryAndSwitchesTimeRange() throws {
        let app = XCUIApplication()
        app.launch()
        app.tabBars.buttons["Statistics"].tap()

        XCTAssertTrue(app.navigationBars["Statistics"].exists)
        XCTAssertTrue(app.staticTexts["Completed priorities"].exists)
        XCTAssertTrue(app.staticTexts["Completion rate"].exists)

        let range = app.segmentedControls["statistics.period"]
        XCTAssertTrue(range.buttons["7 Days"].isSelected)
        range.buttons["30 Days"].tap()
        XCTAssertTrue(range.buttons["30 Days"].isSelected)
        range.buttons["7 Days"].tap()
        XCTAssertTrue(range.buttons["7 Days"].isSelected)

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Statistics"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    @MainActor
    func testStatisticsUpdatesAfterCompletingPriority() throws {
        let app = XCUIApplication()
        app.launch()
        let field = app.textFields["Priority 1"]
        let button = app.buttons["Priority 1 completion"]
        let originalTitle = field.value as? String ?? ""
        let wasEmpty = originalTitle == "Priority 1" || originalTitle.isEmpty
        let wasCompleted = button.value as? String == "Completed"

        if wasCompleted { button.tap() }
        if wasEmpty {
            field.tap()
            field.typeText("Verify statistics\n")
        }

        defer {
            app.tabBars.buttons["Today"].tap()
            if (button.value as? String == "Completed") != wasCompleted {
                button.tap()
            }
            if wasEmpty {
                field.tap()
                field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: "Verify statistics".count) + "\n")
            }
        }

        app.tabBars.buttons["Statistics"].tap()
        let completed = app.descendants(matching: .any)["statistics.completed"].firstMatch
        let before = try XCTUnwrap(Int(try XCTUnwrap(completed.value as? String)))

        app.tabBars.buttons["Today"].tap()
        button.tap()
        app.tabBars.buttons["Statistics"].tap()

        XCTAssertEqual(completed.value as? String, (before + 1).formatted())
        XCTAssertTrue(app.descendants(matching: .any)["statistics.chart"].firstMatch.exists)

        app.swipeUp()
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Statistics with completed priority"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        app.segmentedControls["statistics.period"].buttons["30 Days"].tap()
        let monthScreenshot = XCTAttachment(screenshot: app.screenshot())
        monthScreenshot.name = "Statistics 30 days"
        monthScreenshot.lifetime = .keepAlways
        add(monthScreenshot)
    }

    @MainActor
    func testWidgetLinkOpensTodayFromSettings() throws {
        let app = XCUIApplication()
        app.launch()
        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].exists)

        app.open(try XCTUnwrap(URL(string: "daily3://today")))

        XCTAssertTrue(app.navigationBars["Daily 3"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.textFields["Priority 1"].exists)
        XCTAssertTrue(app.tabBars.buttons["Today"].isSelected)
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
