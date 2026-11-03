import Testing
import Foundation
@testable import LeapCore

/// `leapwidget://` is system-wide, so this parses input any process can send. The
/// allow-list property is asserted directly: the output is always `nil` or one
/// of three constants.
@Suite("URL relay")
struct URLRelayTests {

    // MARK: - Round trip

    @Test(arguments: ClickAction.allCases.filter { $0 != .doNothing })
    func everyActionSurvivesTheRoundTrip(action: ClickAction) throws {
        let relay = try #require(CalendarRelay.url(for: action))

        #expect(relay.scheme == "leapwidget")
        #expect(relay.host == "open-calendar")
        #expect(CalendarRelay.isRelay(relay))
        #expect(CalendarRelay.target(forRelay: relay)?.absoluteString == action.url)
    }

    @Test func doingNothingYieldsNoRelay() {
        #expect(CalendarRelay.url(for: .doNothing) == nil)
    }

    // MARK: - Hostile and malformed input

    @Test(arguments: [
        "leapwidget://open-calendar?action=somethingElse",
        "leapwidget://open-calendar?action=doNothing",           // opens nothing
        "leapwidget://open-calendar?action=",
        "leapwidget://open-calendar",
        "leapwidget://open-calendar?other=appleCalendar",
        "leapwidget://open-calendar?action=AppleCalendar",       // case matters
        "leapwidget://open-calendar?action=%20appleCalendar",    // percent-encoded space
        "leapwidget://open-calendar?action=file:///etc/passwd",
        "leapwidget://open-calendar?action=javascript:alert(1)",
        "leapwidget://open-calendar?action=https://evil.example",
        "leapwidget://elsewhere?action=appleCalendar",           // wrong host
        "https://open-calendar?action=appleCalendar",      // wrong scheme
    ])
    func unknownOrHostileTokensAreRejected(string: String) throws {
        let url = try #require(URL(string: string))

        #expect(CalendarRelay.target(forRelay: url) == nil)
    }

    // MARK: - Is this ours at all

    /// `AppDelegate.handleGetURL` consumes a URL and quits on this answer
    /// alone, before any token is parsed, so scheme and host go together.
    @Test(arguments: [
        ("leapwidget://open-calendar?action=appleCalendar", true),
        ("leapwidget://open-calendar", true),                    // ours, token or not
        ("LEAPWIDGET://open-calendar?action=appleCalendar", true),
        ("leapwidget://Open-Calendar?action=appleCalendar", true),
        ("LEAPWIDGET://OPEN-CALENDAR?action=appleCalendar", true),
        ("notleapwidget://open-calendar?action=appleCalendar", false),
        ("https://open-calendar?action=appleCalendar", false),
        ("file://open-calendar", false),
        ("leapwidget://elsewhere?action=appleCalendar", false),
        ("leapwidget://", false),
        ("mailto:antavik@pm.me", false),
    ])
    func onlyOurSchemeAndHostCountAsARelay(string: String, isOurs: Bool) throws {
        let url = try #require(URL(string: string))

        #expect(CalendarRelay.isRelay(url) == isOurs, "\(string)")
    }

    /// First value wins, and only a known token gets through either way.
    @Test func duplicatedActionTakesTheFirstValue() throws {
        let known = try #require(
            URL(string: "leapwidget://open-calendar?action=fantastical&action=googleCalendar"))
        #expect(CalendarRelay.target(forRelay: known)?.absoluteString
                == ClickAction.fantastical.url)

        let unknown = try #require(
            URL(string: "leapwidget://open-calendar?action=nonsense&action=fantastical"))
        #expect(CalendarRelay.target(forRelay: unknown) == nil)
    }

    /// Scheme and host are case-insensitive; only the token is not.
    @Test(arguments: ["LEAPWIDGET://open-calendar?action=appleCalendar",
                      "leapwidget://Open-Calendar?action=appleCalendar",
                      "LEAPWIDGET://OPEN-CALENDAR?action=appleCalendar"])
    func aMixedCaseSchemeOrHostStillParses(string: String) throws {
        let url = try #require(URL(string: string))
        #expect(CalendarRelay.target(forRelay: url)?.absoluteString
                == ClickAction.appleCalendar.url)
    }

    // MARK: - The allow-list property

    /// No externally supplied string can reach `NSWorkspace.open`.
    @Test(arguments: [
        "leapwidget://open-calendar?action=appleCalendar",
        "leapwidget://open-calendar?action=file:///Applications/Calculator.app",
        "leapwidget://open-calendar?action=x-fantastical3://&action=appleCalendar",
        "leapwidget://open-calendar?action=../../etc",
        "leapwidget://open-calendar?action=googleCalendar#fragment",
    ])
    func theTargetIsAlwaysAConstantOrNil(string: String) throws {
        let url = try #require(URL(string: string))
        let allowed = Set(ClickAction.allCases.compactMap(\.url))

        if let target = CalendarRelay.target(forRelay: url) {
            #expect(allowed.contains(target.absoluteString))
        }
    }
}
