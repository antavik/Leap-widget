import Foundation

/// Remembers which build of the widget extension last ran.
///
/// The widget host keeps one render archive per widget - kind, family, settings
/// and size - and holds it for days before asking for a new one. An app update
/// replaces the extension underneath it, and an archive written while that swap
/// is in flight can end up covering only the appearance in use at that moment.
/// A widget on a surface that wants the other one then has no entry to show but
/// its placeholder, until the archive goes stale days later.
///
/// The first run of a new build is the moment to ask for every timeline again,
/// which replaces those archives without anyone touching a widget.
public struct BuildMarker {
    private let defaults: UserDefaults
    private let key: String

    public init(defaults: UserDefaults = .standard,
                key: String = Constants.Defaults.widgetBuild) {
        self.defaults = defaults
        self.key = key
    }

    /// Records `build` and reports whether it replaced a different one.
    ///
    /// True on the first run of a fresh install as well: there is no archive
    /// worth keeping then either.
    public func advance(to build: String) -> Bool {
        guard defaults.string(forKey: key) != build else { return false }

        defaults.set(build, forKey: key)

        return true
    }
}
