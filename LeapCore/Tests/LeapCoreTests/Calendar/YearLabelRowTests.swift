import Testing
import Foundation
@testable import LeapCore

/// Linear A-79: the two-month widget used to carry ONE year label, taken from
/// the offset-0 month and pinned to the last month shown – so January 2027 in
/// a December row read "JANUARY ’26". Each month now carries the label for its
/// own year whenever the row spans a year boundary.
///
/// `yearLabels` is index-parallel to `models`. `isCurrent` marks the offset-0
/// month (index 0 when the row has none) and decides the colour: the current
/// label keeps the accent, any other renders like a week number.
@Suite("Year labels per month")
struct YearLabelRowTests {
    private static let december = Fixtures.december
    private static let january = DateComponents(year: 2027, month: 1, day: 10, hour: 12)
    private static let august = Fixtures.referenceDay

    private let mondayFirst = Fixtures.mondayFirst

    /// `day` is read in the Gregorian host calendar; `calendar` only decides how
    /// the row's months and years are numbered.
    private func labelledRow(_ day: DateComponents,
                             offsets: [Int],
                             showYear: Bool = true,
                             calendar: Calendar? = nil)
    throws -> (models: [MonthModel], yearLabels: [YearLabel?]) {
        let date = try #require(mondayFirst.date(from: day), "no date for \(day)")

        return monthRow(containing: date,
                        offsets: offsets,
                        showYear: showYear,
                        builder: MonthModelBuilder(calendar: calendar ?? mondayFirst,
                                                   options: MonthOptions()))
    }

    private func label(_ text: String, current: Bool) -> YearLabel {
        YearLabel(text: text, isCurrent: current)
    }

    // MARK: - Spanning rows

    @Test func aDecemberRowLabelsEachMonthWithItsOwnYear() throws {
        let row = try labelledRow(Self.december, offsets: [0, 1])

        #expect(row.models.map(\.title) == ["DECEMBER", "JANUARY"])
        #expect(row.models.map(\.year) == [2026, 2027])
        #expect(row.yearLabels == [label("\u{2019}26", current: true),
                                   label("\u{2019}27", current: false)])
    }

    @Test func aJanuaryRowLabelsEachMonthWithItsOwnYear() throws {
        let row = try labelledRow(Self.january, offsets: [-1, 0])

        #expect(row.models.map(\.title) == ["DECEMBER", "JANUARY"])
        #expect(row.models.map(\.year) == [2026, 2027])
        #expect(row.yearLabels == [label("\u{2019}26", current: false),
                                   label("\u{2019}27", current: true)])
    }

    /// Spanning rows follow the calendar's own year numbering, per month.
    @Test func aSpanningRowOnTheBuddhistCalendarNumbersEachYearInFull() throws {
        let buddhist = Fixtures.calendar(identifier: .buddhist, locale: "en_US")
        let row = try labelledRow(Self.december, offsets: [0, 1], calendar: buddhist)

        #expect(row.yearLabels == [label("2569", current: true),
                                   label("2570", current: false)])
    }

    // MARK: - Non-spanning rows

    /// No boundary in sight: the one label stays on the trailing month, as before.
    @Test func aRowInsideOneYearLabelsOnlyTheLastMonth() throws {
        let row = try labelledRow(Self.august, offsets: [0, 1])

        #expect(row.yearLabels == [nil, label("\u{2019}26", current: true)])
    }

    /// One month cannot span a boundary, even when it is not the current one
    /// (the small widget's next month in December is January 2027).
    @Test func aSingleMonthNeverSpans() throws {
        let row = try labelledRow(Self.december, offsets: [1])

        #expect(row.models.map(\.title) == ["JANUARY"])
        #expect(row.yearLabels == [label("\u{2019}27", current: true)])
    }

    // MARK: - Off and empty

    @Test func withTheYearOffNoMonthIsLabelled() throws {
        let row = try labelledRow(Self.december, offsets: [0, 1], showYear: false)

        #expect(row.models.count == 2)
        #expect(row.yearLabels == [nil, nil])
    }

    @Test func anEmptyRowHasNoModelsAndNoLabels() throws {
        let row = try labelledRow(Self.december, offsets: [])

        #expect(row.models.isEmpty)
        #expect(row.yearLabels.isEmpty)
    }

    // MARK: - Through the widget's entry path

    /// Every entry of the timeline, so a label wired to the wrong index or
    /// computed from the wrong date fails on all three.
    @Test func everyDecemberEntryLabelsDecemberAndJanuaryApart() throws {
        let now = try Fixtures.date(2026, 12, 15, in: mondayFirst)
        let entries = calendarEntries(for: CalendarSettings(monthOffsets: [0, 1], showYear: true),
                                      now: now, calendar: mondayFirst)

        #expect(entries.count == 3)
        for entry in entries {
            #expect(entry.models.map(\.title) == ["DECEMBER", "JANUARY"])
            #expect(entry.yearLabels == [label("\u{2019}26", current: true),
                                         label("\u{2019}27", current: false)])
        }
    }

    @Test func everyJanuaryEntryOfThePreviousCompanionLabelsDecemberAndJanuaryApart() throws {
        let now = try Fixtures.date(2027, 1, 10, in: mondayFirst)
        let entries = calendarEntries(for: CalendarSettings(monthOffsets: [-1, 0], showYear: true),
                                      now: now, calendar: mondayFirst)

        #expect(entries.count == 3)
        for entry in entries {
            #expect(entry.models.map(\.title) == ["DECEMBER", "JANUARY"])
            #expect(entry.yearLabels == [label("\u{2019}26", current: false),
                                         label("\u{2019}27", current: true)])
        }
    }
}
