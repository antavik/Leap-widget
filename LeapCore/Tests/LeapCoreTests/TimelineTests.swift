import Testing
import Foundation
@testable import LeapCore

/// The reload shape. Entry dates are literal dates from a fixed `now`, never
/// compared against `timelineDates` — that is the implementation, and it is
/// covered by `CalendarMathTests.timelineDatesAlignToMidnightAcrossDST`.
@Suite("Timeline")
struct TimelineTests {
    private let settings = CalendarSettings(monthOffsets: [0, 1])

    @Test func threeEntriesAtNowAndTheNextTwoMidnights() throws {
        let calendar = Fixtures.mondayFirst
        let now = try Fixtures.date(2026, 8, 12, hour: 9, in: calendar)
        let entries = calendarEntries(for: settings, now: now, calendar: calendar)

        #expect(entries.count == 3)
        #expect(entries[0].date == now)
        #expect(try entries[1].date == Fixtures.date(2026, 8, 13, hour: 0, in: calendar))
        #expect(try entries[2].date == Fixtures.date(2026, 8, 14, hour: 0, in: calendar))
    }

    @Test func oneSecondBeforeMidnightStillYieldsTheNextTwoMidnights() throws {
        let calendar = Fixtures.mondayFirst
        let almostMidnight = try #require(calendar.date(
            from: DateComponents(year: 2026, month: 8, day: 12,
                                 hour: 23, minute: 59, second: 59)))
        let entries = calendarEntries(for: settings, now: almostMidnight,
                                      calendar: calendar)

        #expect(entries[0].date == almostMidnight)
        #expect(try entries[1].date == Fixtures.date(2026, 8, 13, hour: 0, in: calendar))
        #expect(try entries[2].date == Fixtures.date(2026, 8, 14, hour: 0, in: calendar))
    }

    /// Every entry, not just the first: each is a whole day of display.
    @Test func theTodayMarkerFollowsEachEntry() throws {
        let calendar = Fixtures.mondayFirst
        let now = try Fixtures.date(2026, 8, 12, hour: 9, in: calendar)
        let entries = calendarEntries(for: settings, now: now, calendar: calendar)

        let marked = entries.map { entry -> [Int] in
            entry.models.flatMap { $0.weeks.flatMap { $0 } }
                .filter(\.isToday)
                .map(\.number)
        }

        #expect(marked == [[12], [13], [14]])
    }

    @Test func anEntryCrossingAMonthBoundaryRebuildsToTheNewMonth() throws {
        let calendar = Fixtures.mondayFirst
        let now = try Fixtures.date(2026, 8, 31, hour: 22, in: calendar)
        let entries = calendarEntries(for: CalendarSettings(monthOffsets: [0]),
                                      now: now, calendar: calendar)

        #expect(entries.map { $0.models[0].title } == ["AUGUST", "SEPTEMBER", "SEPTEMBER"])
        #expect(entries.map { $0.models[0].monthNumber } == [8, 9, 9])
    }

    /// A differently configured host must not change the reload's shape.
    @Test(arguments: [Fixtures.mondayFirst, Fixtures.sundayFirst,
                      Fixtures.germanMondayFirst,
                      Fixtures.calendar(identifier: .hebrew, locale: "en_US")])
    func everyCalendarProducesTheSameEntryCount(calendar: Calendar) throws {
        let now = try Fixtures.date(2026, 8, 12, hour: 9, in: calendar)
        let entries = calendarEntries(for: settings, now: now, calendar: calendar)

        #expect(entries.count == 3)
        #expect(entries.allSatisfy { $0.models.count == 2 })
        #expect(entries.allSatisfy { $0.models.allSatisfy { $0.weeks.count == 6 } })
    }

    @Test func aGermanCalendarKeepsItsOwnFirstWeekday() throws {
        let calendar = Fixtures.germanMondayFirst
        let now = try Fixtures.date(2026, 8, 12, hour: 9, in: calendar)
        let entries = calendarEntries(for: settings, now: now, calendar: calendar)
        let headers = try #require(entries.first?.models.first?.weekdayHeaders)

        #expect(headers.first == calendar.veryShortStandaloneWeekdaySymbols[1])   // Montag
    }

    @Test func theClickTargetAndYearLabelRideAlongWithEveryEntry() throws {
        let calendar = Fixtures.mondayFirst
        let now = try Fixtures.date(2026, 8, 12, hour: 9, in: calendar)
        let settings = CalendarSettings(monthOffsets: [0, 1],
                                        showYear: true,
                                        clickAction: .googleCalendar)
        let entries = calendarEntries(for: settings, now: now, calendar: calendar)

        #expect(entries.allSatisfy { $0.clickTarget == .googleCalendar })
        #expect(entries.allSatisfy { $0.yearLabel == "\u{2019}26" })
    }

    @Test func yearLabelIsAbsentWhenTheOptionIsOff() throws {
        let calendar = Fixtures.mondayFirst
        let now = try Fixtures.date(2026, 8, 12, hour: 9, in: calendar)
        let entries = calendarEntries(for: CalendarSettings(monthOffsets: [0],
                                                            showYear: false),
                                      now: now, calendar: calendar)

        #expect(entries.allSatisfy { $0.yearLabel == nil })
    }
}
