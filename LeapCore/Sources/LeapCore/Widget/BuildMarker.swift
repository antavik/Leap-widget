import Foundation

/// Tracks the last widget build that ran.
///
/// The widget host keeps one archived render per widget variant and size. During
/// an app update, a render may be written while the extension is being swapped,
/// leaving stale content until the archive expires. The first run of a new build
/// refreshes those archives without requiring user interaction.
public struct BuildMarker {
    private let defaults: UserDefaults
    private let key: String

    public init(defaults: UserDefaults = .standard,
                key: String = Constants.Defaults.widgetBuild) {
        self.defaults = defaults
        self.key = key
    }

    /// "version (build)".
    public static func build(of bundle: Bundle) -> String {
        let info = bundle.infoDictionary
        let marketing = info?["CFBundleShortVersionString"] as? String ?? "?"
        let number = info?["CFBundleVersion"] as? String ?? "?"

        return "\(marketing) (\(number))"
    }

    /// Like `advance(to:)` without recording.
    public func isBehind(_ build: String) -> Bool {
        defaults.string(forKey: key) != build
    }

    /// Records `build` and returns whether it changed the stored value.
    public func advance(to build: String) -> Bool {
        guard isBehind(build) else { return false }

        defaults.set(build, forKey: key)

        return true
    }
}
