import Foundation
import WidgetKit

public enum AppGroup {
    /// App Group container shared by the host app and the widget extension.
    /// Team-ID-prefixed as macOS requires (§4.1) — the `group.*` form is not
    /// backed by provisioning for Developer ID apps. Replace `TEAMID` with the
    /// real team identifier before signing for distribution; the entitlements
    /// files use `$(TeamIdentifierPrefix)` and pick it up automatically.
    public static let identifier = "TEAMID.com.antavik.quaterly"
}

public enum WidgetKind {
    public static let calendar = "com.antavik.quaterly.calendar"
}

/// Cross-instance defaults stored in the App Group suite (§4.8). Per-widget
/// options live in each widget's intent, not here.
public enum QuaterlySettings {
    public static let launchCalendarSchemeKey = "launchCalendarScheme"
    public static let defaultLaunchCalendarScheme = "ical://"

    static var defaults: UserDefaults {
        UserDefaults(suiteName: AppGroup.identifier) ?? .standard
    }

    public static var launchCalendarScheme: String {
        get {
            defaults.string(forKey: launchCalendarSchemeKey) ?? defaultLaunchCalendarScheme
        }
        set {
            let trimmed = newValue.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed == defaultLaunchCalendarScheme {
                defaults.removeObject(forKey: launchCalendarSchemeKey)
            } else {
                defaults.set(trimmed, forKey: launchCalendarSchemeKey)
            }
        }
    }
}
