import Foundation

public enum Uninstall {

    public static let homebrewPrefixes = [
        URL(filePath: "/opt/homebrew"),
        URL(filePath: "/usr/local")
    ]

    public static let caskToken = "leap"

    public static func channel(prefixes: [URL] = homebrewPrefixes,
                               exists: (URL) -> Bool) -> InstallChannel {
        for prefix in prefixes {
            let receipt = prefix.appending(components: "Caskroom", caskToken)
            let brew = prefix.appending(components: "bin", "brew")

            if exists(receipt), exists(brew) {
                return .homebrew(brew: brew)
            }
        }
        return .direct
    }

    public static func shellEscaped(_ path: String) -> String {
        path.replacing("'", with: "'\\''")
    }

    public static func regexEscaped(_ path: String) -> String {
        path.map { #".[]{}()\*+?^$|"#.contains($0) ? "\\\($0)" : String($0) }.joined()
    }

    public static func trampoline(brew: URL,
                                  script: URL,
                                  log: URL,
                                  processIdentifier: Int32) -> String {
        """
        #!/bin/sh
        exec >'\(shellEscaped(log.path(percentEncoded: false)))' 2>&1

        pid=\(processIdentifier)
        waited=0
        while kill -0 "$pid" 2>/dev/null && [ "$waited" -lt 150 ]; do
            sleep 0.2
            waited=$((waited + 1))
        done

        rm -f '\(shellEscaped(script.path(percentEncoded: false)))'
        exec '\(shellEscaped(brew.path(percentEncoded: false)))' uninstall --cask --zap \(caskToken)
        """
    }

    public static func removalPaths(home: URL, bundle: URL, bundleIdentifier id: String) -> [URL] {
        let library = home.appending(component: "Library")

        return [
            library.appending(components: "Preferences", "\(id).plist"),
            library.appending(components: "Containers", "\(id)"),
            library.appending(components: "Containers", "\(id).widget"),
            library.appending(components: "Application Scripts", "\(id)"),
            library.appending(components: "Application Scripts", "\(id).widget"),
            library.appending(components: "Saved Application State", "\(id).savedState"),
            library.appending(components: "Caches", "\(id)"),
            bundle
        ]
    }
}
