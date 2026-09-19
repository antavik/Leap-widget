import XCTest

@MainActor
enum LeapApp {
    static let safeModeKey = "LEAP_UI_TEST_SAFE_MODE"

    /// `environment` adds values beside the interlock, never instead of it:
    /// the safe-mode key is written last and cannot be overridden.
    static func launched(environment: [String: String] = [:],
                         file: StaticString = #filePath,
                         line: UInt = #line) -> XCUIApplication {
        let fromPlan = ProcessInfo.processInfo.environment[safeModeKey]
        XCTAssertEqual(fromPlan, "1",
                       "Leap.xctestplan no longer sets \(safeModeKey) for the runner",
                       file: file, line: line)

        let app = XCUIApplication()
        environment.forEach { app.launchEnvironment[$0.key] = $0.value }
        // Unconditional: an uninstall confirmation must never be reachable
        // without the guard. This is also the only way a test gets an
        // environment into the app — LaunchServices drops
        // `NSWorkspace.OpenConfiguration.environment` from a sandboxed caller.
        app.launchEnvironment[safeModeKey] = "1"
        app.launch()

        return app
    }
}
