import Testing
import Foundation
@testable import LeapCore

@Suite("Click actions")
struct ClickActionTests {
    @Test func clickActionWireFormatIsStable() throws {
        #expect(ClickAction(rawValue: "appleCalendar")?.url == "ical://")
        #expect(ClickAction(rawValue: "fantastical")?.url == "x-fantastical3://")
        #expect(ClickAction(rawValue: "googleCalendar")?.url == "https://calendar.google.com/")
        #expect(ClickAction(rawValue: "somethingElse") == nil)
        for action in ClickAction.allCases where action != .doNothing {
            let url = try #require(action.url.flatMap(URL.init(string:)))
            #expect(url.scheme != nil)
            #expect(url.scheme != "file")
        }
    }

    @Test func doingNothingOpensNothing() {
        #expect(ClickAction.doNothing.url == nil)
        #expect(CalendarRelay.url(for: .doNothing) == nil)
    }
}
