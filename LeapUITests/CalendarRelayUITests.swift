import XCTest
import AppKit

/// L4 – the half of the widget click this project owns.
///
/// The wire format is pinned at L1 (`URLRelayTests`); what no unit test can
/// reach is the delivery – the `kAEGetURL` handler, the scheme-and-host match,
/// and the fallback chain when the token means nothing to this build.
///
/// **Nothing here launches a calendar.** In safe mode the app resolves the
/// target and writes it to a file this test owns.
///
/// Two neighbouring behaviours stay on the release checklist:
///
/// - **That `widgetURL` is attached at all** – a widget is rendered by
///   WidgetKit in another process and no test host can click it.
/// - **That a *cold* launch by URL relays and then quits.** A sandboxed runner
///   cannot arm safe mode on a cold launch (LaunchServices drops its
///   environment), so the event goes to the running instance instead: same
///   handler, same resolution, and it correctly leaves the app running.
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

    /// An older app reading a newer widget's configuration: it opens the
    /// default calendar, never the unknown token itself.
    func testAnUnknownTokenFallsBackToTheDefaultCalendar() throws {
        try relay("leap://open-calendar?action=somethingElse")

        XCTAssertEqual(try waitForResolvedTarget(), "ical://")
    }

    func testAMissingTokenFallsBackToTheDefaultCalendar() throws {
        try relay("leap://open-calendar")

        XCTAssertEqual(try waitForResolvedTarget(), "ical://")
    }

    /// The allow-list property where the URL actually arrives: the app never
    /// reaches past the parser for its target.
    func testAHostileTokenNeverBecomesTheTarget() throws {
        try relay("leap://open-calendar?action=file:///Applications/Calculator.app")

        XCTAssertEqual(try waitForResolvedTarget(), "ical://")
    }

    // MARK: - Relaying to a running app

    /// The quit belongs to the cold-launch path, which cannot be armed from a
    /// sandboxed runner.
    func testRelayingToARunningAppLeavesItRunning() throws {
        try relay("leap://open-calendar?action=fantastical")
        _ = try waitForResolvedTarget()

        XCTAssertEqual(app.state, .runningForeground)
        XCTAssertTrue(app.windows["Leap"].exists,
                      "the onboarding window disappeared on a relay")
    }

    // MARK: - Delivering the event

    /// A real `kAEGetURL`, the same event a `widgetURL` click produces.
    ///
    /// `createsNewApplicationInstance` is false on purpose: only the instance
    /// `XCUIApplication` launched carries safe mode.
    private func relay(_ string: String) throws {
        // Or the second token in a loop reads the first one's answer.
        try? FileManager.default.removeItem(at: record)

        let url = try XCTUnwrap(URL(string: string))
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        configuration.createsNewApplicationInstance = false

        let delivered = expectation(description: "relay \(string)")
        // Written by the completion handler, read only after `wait(for:)`.
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

    /// The app writes atomically, so a non-empty read is a complete one.
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
