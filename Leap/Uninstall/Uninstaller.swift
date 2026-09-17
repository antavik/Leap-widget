import AppKit
import LeapCore

enum UninstallError: LocalizedError {
    case trashFailed(URL, underlying: any Error)
    case handoffFailed(underlying: any Error)

    var errorDescription: String? {
        switch self {
        case .trashFailed(let url, let underlying):
            String(localized: "Leap could not move “\(url.lastPathComponent)” to the Trash. \(underlying.localizedDescription)",
                   comment: "Uninstall failure message")
        case .handoffFailed(let underlying):
            String(localized: "Leap could not hand the uninstall over to Homebrew. \(underlying.localizedDescription)",
                   comment: "Uninstall failure message")
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .trashFailed:
            String(localized: "Drag Leap to the Trash instead. The Uninstalling section of the read-me lists the remaining files.",
                   comment: "Uninstall failure recovery suggestion")
        case .handoffFailed:
            String(localized: "Run “brew uninstall --cask --zap leap” in Terminal instead.",
                   comment: "Uninstall failure recovery suggestion")
        }
    }
}

@MainActor
enum Uninstaller {

    static func perform() throws {
        deregister()

        switch Uninstall.channel(exists: exists) {
        case .homebrew(let brew):
            try handOver(to: brew)
        case .direct:
            try removeEverything()
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
                                   "-f", regexEscaped(widget.path(percentEncoded: false))])
        }
        run(lsregister, ["-u", Bundle.main.bundleURL.path(percentEncoded: false)])
    }

    // MARK: - Direct install

    private static func removeEverything() throws {
        // cfprefsd owns this domain and writes it back out when Leap quits, so
        // trashing the plist on its own would leave an empty one behind.
        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
        }

        for url in Uninstall.removalPaths(home: FileManager.default.homeDirectoryForCurrentUser,
                                          bundle: Bundle.main.bundleURL) where exists(url) {
            do {
                try FileManager.default.trashItem(at: url, resultingItemURL: nil)
            } catch {
                throw UninstallError.trashFailed(url, underlying: error)
            }
        }
    }

    // MARK: - Homebrew install

    /// Schedules `brew uninstall` for after Leap quits. Deleting the bundle by
    /// hand instead would leave the receipt, and `brew list --cask` would keep
    /// reporting Leap as installed.
    private static func handOver(to brew: URL) throws {
        do {
            try trampoline(brew: brew).write(to: scriptURL, atomically: true, encoding: .utf8)

            let process = Process()
            process.executableURL = URL(filePath: "/bin/sh")
            process.arguments = [scriptURL.path(percentEncoded: false)]
            try process.run()
        } catch {
            throw UninstallError.handoffFailed(underlying: error)
        }
    }

    /// Waits for this process to exit, then lets Homebrew take over. The wait
    /// is bounded: `brew` copes with a still-running app on its own.
    private static func trampoline(brew: URL) -> String {
        """
        #!/bin/sh
        exec >'\(shellEscaped(logURL.path(percentEncoded: false)))' 2>&1

        pid=\(ProcessInfo.processInfo.processIdentifier)
        waited=0
        while kill -0 "$pid" 2>/dev/null && [ "$waited" -lt 150 ]; do
            sleep 0.2
            waited=$((waited + 1))
        done

        rm -f '\(shellEscaped(scriptURL.path(percentEncoded: false)))'
        exec '\(shellEscaped(brew.path(percentEncoded: false)))' uninstall --cask --zap \(Uninstall.caskToken)
        """
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

    /// For single-quoted shell literals: an apostrophe in a path must not
    /// break out of the string.
    private static func shellEscaped(_ path: String) -> String {
        path.replacingOccurrences(of: "'", with: "'\\''")
    }

    /// `pkill -f` takes an extended regular expression, not a literal, so a
    /// bundle at `~/Downloads/Leap (1).app` would match nothing.
    private static func regexEscaped(_ path: String) -> String {
        path.map { #".[]{}()\*+?^$|"#.contains($0) ? "\\\($0)" : String($0) }.joined()
    }
}
