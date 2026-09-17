import Foundation

public enum InstallChannel: Equatable, Sendable {
    case homebrew(brew: URL)
    case direct
}

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

    public static func removalPaths(home: URL, bundle: URL) -> [URL] {
        let library = home.appending(component: "Library")

        return [
            library.appending(components: "Preferences", "com.antavik.leap.plist"),
            library.appending(components: "Containers", "com.antavik.leap"),
            library.appending(components: "Containers", "com.antavik.leap.widget"),
            library.appending(components: "Application Scripts", "com.antavik.leap"),
            library.appending(components: "Application Scripts", "com.antavik.leap.widget"),
            library.appending(components: "Saved Application State", "com.antavik.leap.savedState"),
            library.appending(components: "Caches", "com.antavik.leap"),
            bundle
        ]
    }
}
