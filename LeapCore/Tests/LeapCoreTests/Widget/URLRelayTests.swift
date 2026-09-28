import Testing
import Foundation
@testable import LeapCore

/// `leap://` is system-wide, so this parses input any process can send. The
/// allow-list property is asserted directly: the output is always `nil` or one
/// of three constants.
@Suite("URL relay")
struct URLRelayTests {

    // MARK: - Round trip

    @Test(arguments: ClickAction.allCases.filter { $0 != .doNothing })
    func everyActionSurvivesTheRoundTrip(action: ClickAction) throws {
        let relay = try #require(CalendarRelay.url(for: action))

        #expect(relay.scheme == "leap")
        #expect(relay.host == "open-calendar")
        #expect(CalendarRelay.isRelay(relay))
        #expect(CalendarRelay.target(forRelay: relay)?.absoluteString == action.url)
    }

    @Test func doingNothingYieldsNoRelay() {
        #expect(CalendarRelay.url(for: .doNothing) == nil)
    }

    // MARK: - Hostile and malformed input

    @Test(arguments: [
        "leap://open-calendar?action=somethingElse",
        "leap://open-calendar?action=doNothing",           // opens nothing
        "leap://open-calendar?action=",
        "leap://open-calendar",
        "leap://open-calendar?other=appleCalendar",
        "leap://open-calendar?action=AppleCalendar",       // case matters
        "leap://open-calendar?action=%20appleCalendar",    // percent-encoded space
        "leap://open-calendar?action=file:///etc/passwd",
        "leap://open-calendar?action=javascript:alert(1)",
        "leap://open-calendar?action=https://evil.example",
        "leap://elsewhere?action=appleCalendar",           // wrong host
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
        ("leap://open-calendar?action=appleCalendar", true),
        ("leap://open-calendar", true),                    // ours, token or not
        ("LEAP://open-calendar?action=appleCalendar", true),
        ("leap://Open-Calendar?action=appleCalendar", true),
        ("LEAP://OPEN-CALENDAR?action=appleCalendar", true),
        ("notleap://open-calendar?action=appleCalendar", false),
        ("https://open-calendar?action=appleCalendar", false),
        ("file://open-calendar", false),
        ("leap://elsewhere?action=appleCalendar", false),
        ("leap://", false),
        ("mailto:antavik@pm.me", false),
    ])
    func onlyOurSchemeAndHostCountAsARelay(string: String, isOurs: Bool) throws {
        let url = try #require(URL(string: string))

        #expect(CalendarRelay.isRelay(url) == isOurs, "\(string)")
    }

    /// First value wins, and only a known token gets through either way.
    @Test func duplicatedActionTakesTheFirstValue() throws {
        let known = try #require(
            URL(string: "leap://open-calendar?action=fantastical&action=googleCalendar"))
        #expect(CalendarRelay.target(forRelay: known)?.absoluteString
                == ClickAction.fantastical.url)

        let unknown = try #require(
            URL(string: "leap://open-calendar?action=nonsense&action=fantastical"))
        #expect(CalendarRelay.target(forRelay: unknown) == nil)
    }

    /// Scheme and host are case-insensitive; only the token is not.
    @Test(arguments: ["LEAP://open-calendar?action=appleCalendar",
                      "leap://Open-Calendar?action=appleCalendar",
                      "LEAP://OPEN-CALENDAR?action=appleCalendar"])
    func aMixedCaseSchemeOrHostStillParses(string: String) throws {
        let url = try #require(URL(string: string))
        #expect(CalendarRelay.target(forRelay: url)?.absoluteString
                == ClickAction.appleCalendar.url)
    }

    // MARK: - The allow-list property

    /// No externally supplied string can reach `NSWorkspace.open`.
    @Test(arguments: [
        "leap://open-calendar?action=appleCalendar",
        "leap://open-calendar?action=file:///Applications/Calculator.app",
        "leap://open-calendar?action=x-fantastical3://&action=appleCalendar",
        "leap://open-calendar?action=../../etc",
        "leap://open-calendar?action=googleCalendar#fragment",
    ])
    func theTargetIsAlwaysAConstantOrNil(string: String) throws {
        let url = try #require(URL(string: string))
        let allowed = Set(ClickAction.allCases.compactMap(\.url))

        if let target = CalendarRelay.target(forRelay: url) {
            #expect(allowed.contains(target.absoluteString))
        }
    }
}
