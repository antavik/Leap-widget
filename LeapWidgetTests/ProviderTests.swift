import Testing
import WidgetKit
import Foundation

@Suite("Provider")
struct ProviderTests {
    /// 09:00 stands for any moment of the day. 00:00 is the reload arriving
    /// on time: it must ask for the following midnight, never for itself.
    @Test(arguments: [9, 0])
    func theTimelineReloadsAtTheNextMidnight(hour: Int) throws {
        let calendar = Fixtures.mondayFirst
        let now = try Fixtures.date(2026, 8, 12, hour: hour, in: calendar)
        let nextMidnight = try Fixtures.date(2026, 8, 13, hour: 0, in: calendar)
        let secondMidnight = try Fixtures.date(2026, 8, 14, hour: 0, in: calendar)

        let timeline = Provider<CalendarConfigIntent>()
            .timeline(for: CalendarConfigIntent(), now: now, calendar: calendar)

        #expect(timeline.entries.map(\.date) == [now, nextMidnight, secondMidnight])
        #expect(timeline.policy == .after(nextMidnight))
    }
}
