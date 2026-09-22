import Foundation

/// The `leap://` wire format, written and read in one place.
///
/// `leap://` is system-wide, so this parses input any process can send. Only
/// opaque `ClickPreset` tokens are carried, never URLs, so the output is always
/// `nil` or one of three constants – nothing supplied externally reaches
/// `NSWorkspace.open`.
public enum CalendarRelay {
    public static let scheme = "leap"
    public static let host = "open-calendar"
    public static let actionQueryItem = "action"

    /// `nil` when a click should do nothing.
    public static func url(for preset: ClickPreset?) -> URL? {
        guard let preset else { return nil }

        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        components.queryItems = [URLQueryItem(name: actionQueryItem,
                                              value: preset.rawValue)]

        return components.url
    }

    /// Scheme **and** host. The app consumes a URL and quits on this answer
    /// alone, before any token is parsed, so a host-only match would hand the
    /// app to any `anything://open-calendar`.
    public static func isRelay(_ url: URL) -> Bool {
        components(of: url) != nil
    }

    private static func components(of url: URL) -> URLComponents? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme?.lowercased() == scheme,
              components.host?.lowercased() == host
        else { return nil }

        return components
    }

    public static func preset(forRelay relay: URL) -> ClickPreset? {
        guard let token = components(of: relay)?.queryItems?
                  .first(where: { $0.name == actionQueryItem })?.value
        else { return nil }

        return ClickPreset(rawValue: token)
    }

    public static func target(forRelay relay: URL) -> URL? {
        preset(forRelay: relay).flatMap { URL(string: $0.url) }
    }
}
