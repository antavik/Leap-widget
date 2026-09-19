import AppKit
import LeapCore

enum UninstallError: LocalizedError {
    case handoffFailed(underlying: any Error)

    var errorDescription: String? {
        switch self {
        case .handoffFailed(let underlying):
            String(localized: "Leap could not hand the uninstall over to Homebrew. \(underlying.localizedDescription)",
                   comment: "Uninstall failure message")
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .handoffFailed:
            String(localized: "Run “brew uninstall --cask --zap leap” in Terminal instead.",
                   comment: "Uninstall failure recovery suggestion")
        }
    }
}

@MainActor
enum Uninstaller {

    static func perform() throws -> [URL] {
        deregister()

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
    private static func deregister() {
        if let widget = widgetURL {
            run("/usr/bin/pluginkit", ["-r", widget.path(percentEncoded: false)])
            // A live extension would recreate the container once it is trashed.
            run("/usr/bin/pkill", ["-U", String(getuid()),
                                   "-f", Uninstall.regexEscaped(
                                       widget.path(percentEncoded: false))])
        }
        run(lsregister, ["-u", Bundle.main.bundleURL.path(percentEncoded: false)])
    }

    // MARK: - Direct install

    private static func removeEverything() -> [URL] {
        // cfprefsd owns this domain and writes it back out when Leap quits, so
        // trashing the plist on its own would leave an empty one behind.
        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
        }

        return Uninstall.removalPaths(home: FileManager.default.homeDirectoryForCurrentUser,
                                      bundle: Bundle.main.bundleURL)
            .filter { url in
                guard exists(url) else { return false }
                return (try? FileManager.default.trashItem(at: url, resultingItemURL: nil)) == nil
            }
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
        FileManager.default.temporaryDirectory.appending(component: "leap-uninstall.sh")
    }

    private static var logURL: URL {
        FileManager.default.temporaryDirectory.appending(component: "leap-uninstall.log")
    }

    // MARK: - Helpers

    private static let lsregister =
        "/System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister"

    private static var widgetURL: URL? {
        let url = Bundle.main.bundleURL
            .appending(components: "Contents", "PlugIns", "LeapWidget.appex")
        return exists(url) ? url : nil
    }

    private static func exists(_ url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path(percentEncoded: false))
    }

    /// Best-effort: the caller has already decided that failure is survivable.
    private static func run(_ tool: String, _ arguments: [String]) {
        let process = Process()
        process.executableURL = URL(filePath: tool)
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        guard (try? process.run()) != nil else { return }
        process.waitUntilExit()
    }
}
