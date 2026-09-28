import AppKit
import LeapCore

@MainActor
enum Uninstaller {

    static func perform() async throws -> [URL] {
        await deregister()

        switch Uninstall.channel(exists: exists) {
        case .homebrew(let brew):
            try handOver(to: brew)
            return []
        case .direct:
            return removeEverything()
        }
    }

    // MARK: - Registrations

    /// Best-effort: failure only delays the gallery catching up, since both
    /// services prune records whose bundle has vanished.
    private static func deregister() async {
        if let widget = widgetURL {
            await SystemTool.run("/usr/bin/pluginkit", ["-r", widget.path(percentEncoded: false)])
            // A live extension would recreate the container once it is trashed.
            await SystemTool.run("/usr/bin/pkill", ["-U", String(getuid()),
                                                    "-f", Uninstall.regexEscaped(
                                                        widget.path(percentEncoded: false))])
        }
        await SystemTool.run(SystemTool.lsregister,
                             ["-u", Bundle.main.bundleURL.path(percentEncoded: false)])
    }

    // MARK: - Direct install

    private static func removeEverything() -> [URL] {
        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
            CFPreferencesAppSynchronize(bundleID as CFString)
        }

        var leftovers: [URL] = []
        for url in Uninstall.removalPaths(home: .homeDirectory, bundle: Bundle.main.bundleURL)
        where exists(url) {
            do {
                try FileManager.default.trashItem(at: url, resultingItemURL: nil)
            } catch {
                leftovers.append(url)
            }
        }
        return leftovers
    }

    // MARK: - Homebrew install

    /// Schedules `brew uninstall` for after Leap quits. Deleting the bundle by
    /// hand instead would leave the receipt, and `brew list --cask` would keep
    /// reporting Leap as installed.
    private static func handOver(to brew: URL) throws {
        do {
            let script = Uninstall.trampoline(
                brew: brew,
                script: scriptURL,
                log: logURL,
                processIdentifier: ProcessInfo.processInfo.processIdentifier)
            try script.write(to: scriptURL, atomically: true, encoding: .utf8)

            let process = Process()
            process.executableURL = URL(filePath: "/bin/sh")
            process.arguments = [scriptURL.path(percentEncoded: false)]
            try process.run()
        } catch {
            throw UninstallError.handoffFailed(underlying: error)
        }
    }

    private static var scriptURL: URL {
        URL.temporaryDirectory.appending(component: "leap-uninstall.sh")
    }

    private static var logURL: URL {
        URL.temporaryDirectory.appending(component: "leap-uninstall.log")
    }

    // MARK: - Helpers

    private static var widgetURL: URL? {
        let url = Bundle.main.bundleURL
            .appending(components: "Contents", "PlugIns", "LeapWidget.appex")
        return exists(url) ? url : nil
    }

    private static func exists(_ url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path(percentEncoded: false))
    }
}
