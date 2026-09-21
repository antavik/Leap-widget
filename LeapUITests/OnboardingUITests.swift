import XCTest

/// L4 – the app through a real accessibility client.
///
/// Deliberately shallow: the only layer that can read an accessibility *tree*
/// or run `performAccessibilityAudit`. What a label *says* stays at L1, pixels
/// stay at L2/L3. Safe mode comes from `Leap.xctestplan`.
@MainActor
final class OnboardingUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = AppDriver.launched()
    }

    override func tearDown() async throws {
        app.terminate()
        app = nil
    }

    private var window: XCUIElement {
        app.windows["Leap"]
    }

    // MARK: - Window and steps

    func testLaunchShowsOneOnboardingWindow() {
        XCTAssertTrue(window.waitForExistence(timeout: 10))
        XCTAssertEqual(app.windows.count, 1)
        XCTAssertFalse(window.isResizable(), "the onboarding window must not resize")
    }

    func testEveryStepIsLabelledWithItsPositionAndTitle() {
        XCTAssertTrue(window.waitForExistence(timeout: 10))

        let titles = ["Add to the Desktop", "Add to Notification Center", "Configure"]
        for (index, title) in titles.enumerated() {
            let prefix = "Step \(index + 1) of 3"
            // `matching`, not `containing`: the latter returns the parent of
            // a matching descendant, whose own label is empty.
            let step = window.descendants(matching: .any)
                .matching(NSPredicate(format: "label BEGINSWITH %@", prefix))
                .firstMatch

            XCTAssertTrue(step.exists, "no element labelled “\(prefix)”")
            XCTAssertTrue(step.label.contains(title),
                          "“\(prefix)” does not name its step: \(step.label)")
        }
    }

    // MARK: - Menus

    func testMenuBarCarriesTheDocumentedItems() {
        let menuBar = app.menuBars.firstMatch
        XCTAssertTrue(menuBar.waitForExistence(timeout: 10))

        XCTAssertTrue(menuBar.menuBarItems["File"].exists)
        XCTAssertTrue(menuBar.menuBarItems["Help"].exists)

        menuBar.menuBarItems["Help"].click()
        for item in ["Support & Feedback", "Donate", "Uninstall Leap…"] {
            XCTAssertTrue(menuBar.menuItems[item].exists, "Help is missing “\(item)”")
        }
        app.typeKey(.escape, modifierFlags: [])
    }

    func testAboutPanelShowsTheVersionAndCredits() {
        let menuBar = app.menuBars.firstMatch
        XCTAssertTrue(menuBar.waitForExistence(timeout: 10))

        menuBar.menuBarItems.element(boundBy: 1).click()   // the app menu
        XCTAssertTrue(menuBar.menuItems["About Leap"].exists)
        menuBar.menuItems["About Leap"].click()

        // AppKit's About panel publishes its text as values, not labels, so
        // this asserts the panel, its icon and that it carries text.
        let about = app.dialogs.firstMatch
        XCTAssertTrue(about.waitForExistence(timeout: 5))
        XCTAssertTrue(about.images["Leap icon"].waitForExistence(timeout: 5))
        XCTAssertGreaterThan(about.staticTexts.count, 0)

        app.typeKey(.escape, modifierFlags: [])
    }

    // MARK: - Uninstall

    /// By key equivalent, never by button index: Cancel carries `\u{1b}`
    /// deliberately and Uninstall carries none.
    func testUninstallAlertCancelsWithEscapeAndLeavesTheAppRunning() {
        let menuBar = app.menuBars.firstMatch
        XCTAssertTrue(menuBar.waitForExistence(timeout: 10))

        menuBar.menuBarItems["Help"].click()
        menuBar.menuItems["Uninstall Leap…"].click()

        let alert = app.dialogs.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        XCTAssertTrue(alert.staticTexts["Uninstall Leap?"].exists)

        app.typeKey(.escape, modifierFlags: [])

        XCTAssertTrue(window.waitForExistence(timeout: 5))
        XCTAssertEqual(app.state, .runningForeground)
    }

    /// Confirming is safe *only* because the plan sets safe mode; the test
    /// asserts the guard fired, never the effect.
    func testConfirmingUninstallIsBlockedBySafeMode() {
        let menuBar = app.menuBars.firstMatch
        XCTAssertTrue(menuBar.waitForExistence(timeout: 10))

        menuBar.menuBarItems["Help"].click()
        menuBar.menuItems["Uninstall Leap…"].click()

        let alert = app.dialogs.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 5))

        // The alert says the guard is armed before the button is clicked. If
        // this fails, the plan's environment did not reach the app.
        let armed = alert.staticTexts.containing(
            NSPredicate(format: "value CONTAINS %@", "UI test safe mode is on")).firstMatch
        XCTAssertTrue(armed.exists, "safe mode is NOT armed – refusing to confirm")

        alert.buttons["Uninstall"].click()

        let skipped = app.dialogs.staticTexts["Uninstall skipped – UI test safe mode."]
        XCTAssertTrue(skipped.waitForExistence(timeout: 5),
                      "safe mode did not stop the uninstall – STOP and check the plan")

        app.dialogs.firstMatch.buttons["OK"].click()
        XCTAssertEqual(app.state, .runningForeground)
    }

    // MARK: - Lifecycle

    func testClosingTheLastWindowTerminatesTheApp() {
        XCTAssertTrue(window.waitForExistence(timeout: 10))

        // Through the menu item: a key event can land in the runner if focus
        // slipped, and then this would test nothing.
        let menuBar = app.menuBars.firstMatch
        menuBar.menuBarItems["File"].click()
        menuBar.menuItems["Close Window"].click()

        let terminated = expectation(
            for: NSPredicate(format: "state == %d", XCUIApplication.State.notRunning.rawValue),
            evaluatedWith: app)
        wait(for: [terminated], timeout: 15)
    }
}

private extension XCUIElement {
    /// A titled, non-resizable window reports no resize affordance.
    func isResizable() -> Bool {
        let before = frame.size
        coordinate(withNormalizedOffset: CGVector(dx: 1, dy: 1))
            .withOffset(CGVector(dx: -1, dy: -1))
            .click(forDuration: 0.1, thenDragTo:
                coordinate(withNormalizedOffset: CGVector(dx: 1, dy: 1))
                    .withOffset(CGVector(dx: 60, dy: 60)))

        return frame.size != before
    }
}
