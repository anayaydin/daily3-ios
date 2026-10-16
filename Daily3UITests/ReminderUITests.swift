import XCTest

final class ReminderUITests: XCTestCase {
    @MainActor
    func testRemindersRequestPermissionAndPersistAcrossLaunches() throws {
        let app = XCUIApplication()
        app.launch()
        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].exists)

        let morning = app.switches["reminder.morning.enabled"].firstMatch
        let evening = app.switches["reminder.evening.enabled"].firstMatch
        XCTAssertTrue(morning.waitForExistence(timeout: 5))
        let morningWasEnabled = morning.value as? String == "1"
        let eveningWasEnabled = evening.value as? String == "1"

        defer {
            setSwitch(morning, enabled: morningWasEnabled)
            setSwitch(evening, enabled: eveningWasEnabled)
        }

        if morningWasEnabled { setSwitch(morning, enabled: false) }
        tapSwitch(morning)

        let permissionAlert = XCUIApplication(bundleIdentifier: "com.apple.springboard").alerts.firstMatch
        if permissionAlert.waitForExistence(timeout: 5) {
            permissionAlert.buttons["Allow"].tap()
        }
        waitForSwitch(morning, enabled: true)
        setSwitch(evening, enabled: true)
        XCTAssertEqual(app.descendants(matching: .any)["reminder.permission"].firstMatch.value as? String, "Allowed")

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Reminder settings"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        app.terminate()
        app.launch()
        app.tabBars.buttons["Settings"].tap()
        waitForSwitch(morning, enabled: true)
        waitForSwitch(evening, enabled: true)

        setSwitch(morning, enabled: false)
        waitForSwitch(evening, enabled: true)
    }

    @MainActor
    private func setSwitch(_ toggle: XCUIElement, enabled: Bool) {
        if (toggle.value as? String == "1") != enabled {
            tapSwitch(toggle)
        }
        waitForSwitch(toggle, enabled: enabled)
    }

    @MainActor
    private func tapSwitch(_ toggle: XCUIElement) {
        let control = toggle.switches.firstMatch
        if control.exists {
            control.tap()
        } else {
            toggle.tap()
        }
    }

    @MainActor
    private func waitForSwitch(_ toggle: XCUIElement, enabled: Bool) {
        let predicate = NSPredicate(format: "value == %@", enabled ? "1" : "0")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: toggle)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 10), .completed)
    }
}
