import Foundation

/// Switches `Leap.xctestplan` sets, never a per-test launch argument.
enum LaunchEnvironment {
    static var isUITestSafeMode: Bool {
        environment["LEAP_UI_TEST_SAFE_MODE"] == "1"
    }

    /// Where a relayed click is written instead of opening a calendar.
    static var relayRecordURL: URL? {
        guard isUITestSafeMode,
              let path = environment["LEAP_UI_TEST_RELAY_RECORD"]
        else { return nil }

        return URL(filePath: path)
    }

    private static var environment: [String: String] {
        ProcessInfo.processInfo.environment
    }
}
