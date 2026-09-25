import XCTest
import AppKit

/// L4 – `kAEGetURL` delivery and fallback chain (wire format is in `URLRelayTests`).
///
/// No calendar launches: in safe mode the app writes the resolved target to a file.
///
/// Manual release checks: `widgetURL` is attached (untestable out of process),
/// and a cold launch by URL relays then quits (safe mode can't be armed on a
/// cold launch).
@MainActor
final class CalendarRelayUITests: XCTestCase {
    private var app: XCUIApplication!
    private var record: URL!

    override func setUp() async throws {
        continueAfterFailure = false

        record = FileManager.default.temporaryDirectory
            .appending(component: "leap-relay-\(UUID().uuidString).txt")
        app = AppDriver.launched(environment: [Self.recordKey: recordPath])
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: record)
        app.terminate()
        app = nil
    }

    private static let recordKey = "LEAP_UI_TEST_RELAY_RECORD"
    private var recordPath: String { record.path(percentEncoded: false) }

    // MARK: - Every preset reaches its own calendar

    func testEachPresetResolvesToItsOwnCalendarURL() throws {
        for (token, expected) in [("appleCalendar", "ical://"),
                                  ("fantastical", "x-fantastical3://"),
                                  ("googleCalendar", "https://calendar.google.com/")] {
            try relay("leap://open-calendar?action=\(token)")

            XCTAssertEqual(try waitForResolvedTarget(), expected,
                           "?action=\(token) resolved to the wrong calendar")
        }
    }

    // MARK: - The fallback chain

    /// Older app, newer widget config: opens the default calendar.
    func testAnUnknownTokenFallsBackToTheDefaultCalendar() throws {
        try relay("leap://open-calendar?action=somethingElse")

        XCTAssertEqual(try waitForResolvedTarget(), "ical://")
    }

    func testAMissingTokenFallsBackToTheDefaultCalendar() throws {
        try relay("leap://open-calendar")

        XCTAssertEqual(try waitForResolvedTarget(), "ical://")
    }

    /// The target always comes from the allow-list, never the token.
    func testAHostileTokenNeverBecomesTheTarget() throws {
        try relay("leap://open-calendar?action=file:///Applications/Calculator.app")

        XCTAssertEqual(try waitForResolvedTarget(), "ical://")
    }

    // MARK: - Relaying to a running app

    /// Checks running, not frontmost: activation is up to the system
    /// (macOS 27 leaves the app in the background).
    func testRelayingToARunningAppLeavesItRunning() throws {
        try relay("leap://open-calendar?action=fantastical")
        _ = try waitForResolvedTarget()

        XCTAssertFalse(app.wait(for: .notRunning, timeout: 2),
                       "the app quit after a relay to a running instance")
        XCTAssertTrue([.runningForeground, .runningBackground].contains(app.state),
                      "unexpected app state \(app.state.rawValue) after a relay")
        XCTAssertTrue(app.windows["Leap"].exists,
                      "the onboarding window disappeared on a relay")
    }

    // MARK: - Delivering the event

    /// Sends a real `kAEGetURL` to the launched instance (the only one in safe mode).
    private func relay(_ string: String) throws {
        // Clear the previous answer.
        try? FileManager.default.removeItem(at: record)

        let url = try XCTUnwrap(URL(string: string))
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        configuration.createsNewApplicationInstance = false

        let delivered = expectation(description: "relay \(string)")
        // Read only after `wait(for:)`.
        nonisolated(unsafe) var failure: (any Error)?

        NSWorkspace.shared.open([url],
                                withApplicationAt: try Self.appBundle(),
                                configuration: configuration) { _, error in
            failure = error
            delivered.fulfill()
        }

        wait(for: [delivered], timeout: 30)
        if let failure { throw failure }
    }

    /// Atomic write, so non-empty means complete.
    private func waitForResolvedTarget(timeout: TimeInterval = 10) throws -> String {
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            if let text = try? String(contentsOf: record, encoding: .utf8), !text.isEmpty {
                return text.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }

        XCTFail("the app resolved no calendar URL within \(timeout)s")

        return ""
    }

    /// The built `Leap.app`, found beside the test bundle.
    private static func appBundle() throws -> URL {
        var directory = Bundle(for: CalendarRelayUITests.self).bundleURL

        for _ in 0..<4 {
            directory = directory.deletingLastPathComponent()
            let candidate = directory.appending(component: "Leap.app")
            if FileManager.default.fileExists(atPath: candidate.path(percentEncoded: false)) {
                return candidate
            }
        }

        throw XCTSkip("Leap.app is not beside the test bundle")
    }
}
