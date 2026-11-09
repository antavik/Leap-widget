import Testing
import WidgetKit
import Foundation
import LeapCore

/// The timeline policy that keeps the today marker right: a fresh reload at
/// the *first* future local midnight, not `.atEnd` after the second one. A
/// fixed Gregorian/GMT calendar and fixed dates make every expectation exact.
@Suite("Provider")
struct ProviderTests {
    private static let calendar = Fixtures.calendar(locale: "en_GB")

    /// now + the next two midnights, in order — A-81 must keep the entries.
    private func checkEntries(_ timeline: Timeline<CalendarEntry>,
                              now: Date,
                              firstMidnight: Date,
                              secondMidnight: Date,
                              sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(timeline.entries.map(\.date) == [now, firstMidnight, secondMidnight],
               "entries \(timeline.entries.map(\.date)), expected [\(now), \(firstMidnight), \(secondMidnight)]",
               sourceLocation: sourceLocation)
    }

    /// The policy is `.after(firstMidnight)` — never `.atEnd`, and never a
    /// reload scheduled at `now` itself.
    private func checkPolicy(_ timeline: Timeline<CalendarEntry>,
                             now: Date,
                             firstMidnight: Date,
                             sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(timeline.policy == .after(firstMidnight),
               "expected .after(\(firstMidnight)), got \(timeline.policy)",
               sourceLocation: sourceLocation)
        #expect(firstMidnight > now,
               "reload must be strictly after now, not at now",
               sourceLocation: sourceLocation)
    }

    /// Mid-morning request: the entries are unchanged, but the reload is at
    /// the *first* future midnight — long before the second midnight that
    /// `.atEnd` would wait for.
    @Test func aMorningTimelineReloadsAtTheFirstMidnight() async throws {
        let calendar = Self.calendar
        let now = try Fixtures.date(2026, 8, 12, hour: 9, in: calendar)
        let firstMidnight = try Fixtures.date(2026, 8, 13, hour: 0, in: calendar)
        let secondMidnight = try Fixtures.date(2026, 8, 14, hour: 0, in: calendar)

        let timeline = await Provider<CalendarConfigIntent>()
            .timeline(for: CalendarConfigIntent(), now: now, calendar: calendar)

        checkEntries(timeline, now: now, firstMidnight: firstMidnight, secondMidnight: secondMidnight)
        checkPolicy(timeline, now: now, firstMidnight: firstMidnight)
    }

    /// At exactly local midnight the "next midnight" is already the *next
    /// day's*: the reload is strictly after `now` (no `.after(now)` churn),
    /// and the entry dates still start at `now`.
    @Test func aMidnightTimelineReloadsAtTheNextDaysMidnight() async throws {
        let calendar = Self.calendar
        let now = try Fixtures.date(2026, 8, 12, hour: 0, in: calendar)
        let nextMidnight = try Fixtures.date(2026, 8, 13, hour: 0, in: calendar)
        let secondMidnight = try Fixtures.date(2026, 8, 14, hour: 0, in: calendar)

        let timeline = await Provider<CalendarConfigIntent>()
            .timeline(for: CalendarConfigIntent(), now: now, calendar: calendar)

        checkEntries(timeline, now: now, firstMidnight: nextMidnight, secondMidnight: secondMidnight)
        checkPolicy(timeline, now: now, firstMidnight: nextMidnight)
    }
}
