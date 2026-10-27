import AppKit
import OSLog
import LeapCore

extension AppDelegate {
    private static let log = Logger(category: "Uninstall")

    /// Deliberately unlocalized: they are test fixtures, never shipped copy.
    static let safeModeArmedMessage = "UI test safe mode is on – nothing will be removed."
    static let safeModeMessage = "Uninstall skipped – UI test safe mode."

    @objc func confirmUninstall() {
        guard !isUninstalling else { return }

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = String(localized: "Uninstall Leap?",
                                   comment: "Uninstall confirmation title")
        let message = String(
            localized: "Leap and its settings will be moved to the Trash, and its widgets will disappear from the Desktop and Notification Center.",
            comment: "Uninstall confirmation message")

        alert.informativeText = LaunchEnvironment.isUITestSafeMode
            ? "\(message)\n\n\(Self.safeModeArmedMessage)"
            : message

        let uninstall = alert.addButton(
            withTitle: String(localized: "Uninstall", comment: "Uninstall confirmation button"))
        let cancel = alert.addButton(
            withTitle: String(localized: "Cancel", comment: "Uninstall confirmation button"))

        uninstall.hasDestructiveAction = true
        uninstall.keyEquivalent = ""
        cancel.keyEquivalent = "\u{1b}"

        NSApp.activate()

        guard alert.runModal() == .alertFirstButtonReturn else { return }

        // `Uninstaller.perform()` is not sandboxed to a test's copy of the app:
        // it trashes the real user's preferences and containers, and on a cask
        // machine runs `brew uninstall --cask --zap`. Safe mode comes from the
        // test plan, so no future UI test can forget it.
        guard !LaunchEnvironment.isUITestSafeMode else {
            let paths = Uninstall.removalPaths(home: .homeDirectory,
                                               bundle: Bundle.main.bundleURL,
                                               bundleIdentifier: Constants.Bundles.current)
            Self.log.info("LEAP_UI_TEST_SAFE_MODE: skipped uninstall of \(paths.count) paths")
            for path in paths {
                Self.log.info("LEAP_UI_TEST_SAFE_MODE: would remove \(path.path(percentEncoded: false), privacy: .public)")
            }

            // Surfaced, not just logged: an XCUITest can read a window.
            let skipped = NSAlert()
            skipped.alertStyle = .informational
            skipped.messageText = Self.safeModeMessage
            skipped.informativeText = paths
                .map { $0.path(percentEncoded: false) }
                .joined(separator: "\n")
            skipped.addButton(withTitle: "OK")
            skipped.runModal()

            return
        }

        isUninstalling = true
        Task {
            defer { isUninstalling = false }
            do {
                report(leftovers: try await Uninstaller.perform())
                NSApp.terminate(nil)
            } catch {
                NSAlert(error: error).runModal()
            }
        }
    }

    private func report(leftovers: [URL]) {
        guard !leftovers.isEmpty else { return }

        let list = leftovers
            .map { "  " + NSString(string: $0.path(percentEncoded: false)).abbreviatingWithTildeInPath }
            .joined(separator: "\n")

        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = String(localized: "Leap is gone, but a few of its files are not.",
                                   comment: "Uninstall leftovers title")
        alert.informativeText = String(
            localized: "macOS keeps these out of reach of every app but Finder:\n\n\(list)\n\nDrag them to the Trash to finish up.",
            comment: "Uninstall leftovers message")

        alert.addButton(withTitle: String(localized: "Show in Finder",
                                          comment: "Uninstall leftovers button"))
        alert.addButton(withTitle: String(localized: "OK",
                                          comment: "Uninstall leftovers button"))

        guard alert.runModal() == .alertFirstButtonReturn else { return }

        NSWorkspace.shared.activateFileViewerSelecting(leftovers)
    }
}
