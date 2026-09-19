import Testing
import Foundation
@testable import LeapCore

/// ISO vs US numbering and the override between them — their own rules, so
/// their own suite rather than hiding inside the grid tests.
@Suite("Week numbering")
struct WeekNumberingTests {
    private let mondayFirst = Fixtures.mondayFirst
    private let sundayFirst = Fixtures.sundayFirst

    private func model(_ year: Int, _ month: Int, _ day: Int,
                       calendar: Calendar,
                       options: MonthOptions = MonthOptions()) throws -> MonthModel {
        let reference = try Fixtures.date(year, month, day, in: calendar)
        return monthModel(containing: reference, offset: 0, calendar: calendar,
                          today: reference, options: options)
    }

    @Test func isoWeekNumbersMondayFirst() throws {
        // 2026 is an ISO W53 year; December's last in-month row starts Mon Dec 28,
        // and the trailing all-January row already carries W1 of 2027.
        let december = try model(2026, 12, 15, calendar: mondayFirst,
                                 options: MonthOptions(showWeekNumbers: true))
        #expect(december.weekNumbers == [49, 50, 51, 52, 53, 1])
        // January 2027's first row still belongs to ISO week 53 of 2026; W1 starts
        // Monday Jan 4.
        let january = try model(2027, 1, 10, calendar: mondayFirst,
                                options: MonthOptions(showWeekNumbers: true))
        #expect(january.weekNumbers?.first == 53)
        #expect(january.weekNumbers?[1] == 1)
    }

    @Test func usWeekNumbersSundayFirst() throws {
        // US numbering: the week of Sun Dec 27 2026 contains Jan 1 → already week 1;
        // the trailing all-January row is week 2.
        let december = try model(2026, 12, 15, calendar: sundayFirst,
                                 options: MonthOptions(showWeekNumbers: true))
        #expect(december.weekNumbers?[4] == 1)
        #expect(december.weekNumbers?.last == 2)
        let january = try model(2027, 1, 10, calendar: sundayFirst,
                                options: MonthOptions(showWeekNumbers: true))
        #expect(january.weekNumbers?.first == 1)
    }

    @Test func mondayOverrideForcesISONumbering() throws {
        // A US calendar (minimumDaysInFirstWeek = 1) with a Monday override must
        // switch to ISO numbering: Jan 1–3 2027 stay in week 53 of 2026.
        let january = try model(2027, 1, 10, calendar: sundayFirst,
                                options: MonthOptions(firstWeekday: 2,
                                                      showWeekNumbers: true))
        #expect(january.weekNumbers?.first == 53)
        #expect(january.weekNumbers?[1] == 1)
    }

    @Test func sundayOverrideDropsRegionalISONumbering() throws {
        // en_GB: Monday-first, 4-day rule. Overridden to Sunday, Jan 2027's first
        // row is week 1 under the US rule; the hybrid would have said 53.
        let january = try model(2027, 1, 10, calendar: mondayFirst,
                                options: MonthOptions(firstWeekday: 1,
                                                      showWeekNumbers: true))
        #expect(january.weekNumbers?.first == 1)
    }

    @Test func weekNumbersAbsentWhenDisabled() throws {
        #expect(try model(2026, 8, 12, calendar: mondayFirst).weekNumbers == nil)
    }
}
