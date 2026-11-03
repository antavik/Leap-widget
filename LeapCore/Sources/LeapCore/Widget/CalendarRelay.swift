import Foundation

/// The `leapwidget://` wire format, written and read in one place.
///
/// `leapwidget://` is system-wide, so this parses input any process can send. Only
/// opaque `ClickAction` tokens are carried, never URLs, so the output is always
/// `nil` or one of three constants – nothing supplied externally reaches
/// `NSWorkspace.open`.
public enum CalendarRelay {
    public static let scheme = "leapwidget"
    public static let host = "open-calendar"
    public static let actionQueryItem = "action"

    /// `nil` when a click should do nothing.
    public static func url(for action: ClickAction) -> URL? {
        guard action.url != nil else { return nil }

        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        components.queryItems = [URLQueryItem(name: actionQueryItem,
                                              value: action.rawValue)]

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

    /// `nil` for `.doNothing` and anything unknown.
    public static func target(forRelay relay: URL) -> URL? {
        components(of: relay)?.queryItems?
            .first { $0.name == actionQueryItem }?.value
            .flatMap(ClickAction.init(rawValue:))?.url
            .flatMap(URL.init(string:))
    }
}
