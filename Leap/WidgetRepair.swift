import AppKit
import CoreServices
import OSLog
import WidgetKit
import LeapCore

/// Fixes what an update leaves behind: stray copies' LaunchServices records
/// make the host reject renders, and cached renders miss appearances until
/// the host restarts. Runs on the first launch of each build and from
/// Help ▸ Repair Widgets.
@MainActor
enum WidgetRepair {
    enum Outcome {
        case repaired
        case skipped            // UI test safe mode
        case hostRestartFailed
    }

    private static let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.antavik.leap",
                                    category: "WidgetRepair")

    static func onLaunch() async {
        guard !(await repairIfUpdated()) else { return }

        await register()
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Marks the build repaired only on success, so a failed repair retries.
    @discardableResult
    static func repairIfUpdated() async -> Bool {
        // Debug builds rebuild constantly; don't flicker widgets each time.
#if DEBUG
        return false
#else
        let build = BuildMarker.build(of: .main)
        let marker = BuildMarker(key: Constants.Defaults.repairedBuild)

        guard !AppDelegate.isUITestSafeMode, ownsWidget, marker.isBehind(build),
              await repair() == .repaired
        else { return false }

        marker.advance(to: build)

        return true
#endif
    }

    @discardableResult
    static func repair() async -> Outcome {
        // The restart would redraw the real user's Desktop.
        guard !AppDelegate.isUITestSafeMode else {
            log.info("LEAP_UI_TEST_SAFE_MODE: skipped widget repair")
            return .skipped
        }

        log.info("Repairing widgets for \(BuildMarker.build(of: .main), privacy: .public)")

#if !DEBUG
        // Debug builds must never take over the gallery from the installed app.
        if ownsWidget {
            let strays = StrayCopies.among(
                NSWorkspace.shared.urlsForApplications(withBundleIdentifier: bundleIdentifier),
                running: Bundle.main.bundleURL)
            await unregister(strays)
        }
#endif

        await register()

        guard await restartWidgetHost() else {
            log.error("Could not restart the widget host")
            return .hostRestartFailed
        }

        WidgetCenter.shared.reloadAllTimelines()

        return .repaired
    }

    // MARK: - Steps

    /// Records only; files stay.
    private static func unregister(_ copies: [URL]) async {
        for copy in copies {
            log.info("Unregistering stray copy \(copy.path(percentEncoded: false), privacy: .public)")

            await SystemTool.run("/usr/bin/pluginkit",
                                 ["-r", widget(in: copy).path(percentEncoded: false)])
            await SystemTool.run(SystemTool.lsregister,
                                 ["-u", copy.path(percentEncoded: false)])
        }
    }

    private static func register() async {
#if !DEBUG
        guard ownsWidget else {
            log.info("Not registering \(Bundle.main.bundleURL.path(percentEncoded: false), privacy: .public): only an installed copy owns the widget")
            return
        }

        let app = Bundle.main.bundleURL

        await Task.detached(priority: .utility) {
            LSRegisterURL(app as CFURL, true)
        }.value

        await SystemTool.run("/usr/bin/pluginkit",
                             ["-a", widget(in: app).path(percentEncoded: false)])
#endif
    }

    /// Both relaunch on demand; widgets flicker once.
    private static func restartWidgetHost() async -> Bool {
        await SystemTool.run("/usr/bin/killall", ["chronod", "NotificationCenter"]) == 0
    }

    // MARK: - Helpers

    private static var ownsWidget: Bool {
        InstallLocation.ownsWidget(Bundle.main.bundleURL, home: .homeDirectory)
    }

    private static var bundleIdentifier: String {
        Bundle.main.bundleIdentifier ?? "com.antavik.leap"
    }

    private static func widget(in app: URL) -> URL {
        app.appending(components: "Contents", "PlugIns", "LeapWidget.appex")
    }
}
