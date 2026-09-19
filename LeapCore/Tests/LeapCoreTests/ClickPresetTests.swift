import Testing
import Foundation
@testable import LeapCore

@Suite("Click presets")
struct ClickPresetTests {
    @Test func clickPresetWireFormatIsStable() throws {
        #expect(ClickPreset(rawValue: "appleCalendar")?.url == "ical://")
        #expect(ClickPreset(rawValue: "fantastical")?.url == "x-fantastical3://")
        #expect(ClickPreset(rawValue: "googleCalendar")?.url == "https://calendar.google.com/")
        #expect(ClickPreset(rawValue: "somethingElse") == nil)
        for preset in ClickPreset.allCases {
            let url = try #require(URL(string: preset.url))
            #expect(url.scheme != nil)
            #expect(url.scheme != "file")
        }
    }
}
