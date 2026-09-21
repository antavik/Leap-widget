import Testing
import Foundation
@testable import LeapCore

@Suite("Calendar math")
struct CalendarMathTests {
    private let mondayFirst = Fixtures.mondayFirst
    private let sundayFirst = Fixtures.sundayFirst
    private let fridaySaturdayWeekend = Fixtures.fridaySaturdayWeekend

    private func date(_ year: Int, _ month: Int, _ day: Int,
                      in calendar: Calendar) throws -> Date {
        try Fixtures.date(year, month, day, in: calendar)
    }

    private func model(_ year: Int, _ month: Int, _ day: Int,
                       offset: Int = 0,
                       calendar: Calendar,
                       options: MonthOptions = MonthOptions()) throws -> MonthModel {
        let reference = try date(year, month, day, in: calendar)
        return monthModel(containing: reference,
                          offset: offset,
                          calendar: calendar,
                          today: reference,
                          options: options)
    }

    // MARK: - Grid layout

    @Test func augustMondayFirstHasSixRows() throws {
        let august = try model(2026, 8, 12, calendar: mondayFirst)
        #expect(august.title == "AUGUST")
        #expect(august.year == 2026)
        #expect(august.weeks.count == 6)
        // Aug 1 2026 is a Saturday → five leading July days in a Monday-first grid.
        #expect(august.weeks[0].prefix(5).allSatisfy { $0.isOutsideMonth })
        #expect(august.weeks[0].prefix(5).map(\.number) == [27, 28, 29, 30, 31])
        #expect(august.weeks[0][5].number == 1)
        #expect(august.weeks[0][5].isOutsideMonth == false)
        // Aug 31 is a Monday → the last row starts with it and fills with September.
        #expect(august.weeks[5][0].number == 31)
        #expect(august.weeks[5][0].isOutsideMonth == false)
        #expect(august.weeks[5].dropFirst().allSatisfy { $0.isOutsideMonth })
        #expect(august.weeks[5].dropFirst().map(\.number) == [1, 2, 3, 4, 5, 6])
    }

    @Test func augustSundayFirstLayout() throws {
        let august = try model(2026, 8, 12, calendar: sundayFirst)
        #expect(august.weeks.count == 6)
        // Sunday-first: Saturday Aug 1 lands in the last column, after six July days.
        #expect(august.weeks[0].prefix(6).allSatisfy { $0.isOutsideMonth })
        #expect(august.weeks[0][6].number == 1)
        #expect(august.weeks[0][6].isOutsideMonth == false)
    }

    @Test func shortMonthsStillFillSixRows() throws {
        // Feb 2026 starts on Sunday and has 28 days → 4 exact rows Sunday-first,
        // so the last two rows are entirely March.
        let february = try model(2026, 2, 10, calendar: sundayFirst)
        #expect(february.weeks.count == 6)
        #expect(february.weeks[3][6].number == 28)
        #expect(february.weeks[3][6].isOutsideMonth == false)
        #expect(february.weeks[4].allSatisfy { $0.isOutsideMonth })
        #expect(february.weeks[5].allSatisfy { $0.isOutsideMonth })
        #expect(february.weeks[4].map(\.number) == [1, 2, 3, 4, 5, 6, 7])

        // Leap Feb 2024 (starts Thursday, 29 days) ends mid-row Monday-first.
        let leap = try model(2024, 2, 10, calendar: mondayFirst)
        #expect(leap.weeks.count == 6)
        #expect(leap.weeks[4][3].number == 29)
        #expect(leap.weeks[4][3].isOutsideMonth == false)
        #expect(leap.weeks[4][4].number == 1)
        #expect(leap.weeks[4][4].isOutsideMonth)
    }

    @Test func outsideDaysToggleReachesModel() throws {
        #expect(try model(2026, 8, 12, calendar: mondayFirst).showsOutsideDays)
        let hidden = try model(2026, 8, 12, calendar: mondayFirst,
                               options: MonthOptions(showOutsideDays: false))
        #expect(hidden.showsOutsideDays == false)
    }

    @Test func headerRotationMatchesLayoutForEveryOverride() throws {
        let symbols = mondayFirst.veryShortStandaloneWeekdaySymbols
        for override in 1...7 {
            let options = MonthOptions(firstWeekday: override)
            let august = try model(2026, 8, 12, calendar: sundayFirst, options: options)
            // Header starts with the overridden weekday…
            #expect(august.weekdayHeaders.first == symbols[override - 1])
            // …and the layout agrees: Aug 1 2026 is a Saturday (weekday 7), so its
            // column equals the distance from the effective first weekday.
            let expectedColumn = (7 - override + 7) % 7
            #expect(august.weeks[0][expectedColumn].number == 1)
            #expect(august.weeks[0][expectedColumn].isOutsideMonth == false)
            #expect(august.weeks[0].prefix(expectedColumn).allSatisfy { $0.isOutsideMonth })
        }
    }

    @Test func nonGregorianCalendarsBuildWellFormedMonths() throws {
        for identifier in [Calendar.Identifier.hebrew, .islamicUmmAlQura,
                           .buddhist, .japanese] {
            let calendar = Fixtures.calendar(identifier: identifier, locale: "en_US")
            let builder = MonthModelBuilder(calendar: calendar,
                                            options: MonthOptions(showWeekNumbers: true))
            let start = Date(timeIntervalSince1970: 1_704_628_800)   // 2024-01-07

            // Two years of consecutive months covers a Hebrew leap year's month 13.
            for offset in 0..<24 {
                let month = builder.model(containing: start, offset: offset, today: start)
                let where_ = "identifier=\(identifier) offset=\(offset)"
                #expect(month.weeks.count == 6, Comment(rawValue: where_))
                #expect(month.weeks.allSatisfy { $0.count == 7 }, Comment(rawValue: where_))
                #expect(month.weekdayHeaders.count == 7, Comment(rawValue: where_))
                #expect(month.weekNumbers?.count == 6, Comment(rawValue: where_))
                #expect(!month.title.isEmpty, Comment(rawValue: where_))
            }
        }
    }

    // MARK: - Today marker

    @Test func todayMarkedOnlyInCurrentMonth() throws {
        let reference = try date(2026, 8, 12, in: mondayFirst)
        for offset in [-1, 0, 1] {
            let month = monthModel(containing: reference,
                                   offset: offset,
                                   calendar: mondayFirst,
                                   today: reference,
                                   options: MonthOptions())
            let todays = month.weeks.flatMap { $0 }.filter(\.isToday)
            if offset == 0 {
                #expect(todays.map(\.number) == [12])
            } else {
                #expect(todays.isEmpty)
            }
        }
    }

    @Test func outsideDayMatchingTodayIsNotMarked() throws {
        // Today Aug 1 2026 appears as a trailing day in July's grid – no marker there.
        let july = try date(2026, 7, 15, in: mondayFirst)
        let today = try date(2026, 8, 1, in: mondayFirst)
        let month = monthModel(containing: july, offset: 0,
                               calendar: mondayFirst, today: today,
                               options: MonthOptions())
        let trailing = month.weeks.flatMap { $0 }.filter(\.isOutsideMonth)
        #expect(trailing.contains { $0.number == 1 })
        #expect(month.weeks.flatMap { $0 }.allSatisfy { !$0.isToday })
    }

    // MARK: - Month number

    @Test func monthNumberFollowsTheDisplayedMonth() throws {
        let options = MonthOptions(monthNumberStyle: .arabic)
        for (offset, expected) in [(-1, 7), (0, 8), (1, 9)] {
            let displayed = try model(2026, 8, 12, offset: offset,
                                      calendar: mondayFirst, options: options)
            #expect(displayed.monthNumber == expected)
            #expect(displayed.monthNumberLabel == String(expected))
        }
    }

    @Test func monthNumberWrapsAcrossTheYearBoundary() throws {
        let january = try model(2026, 12, 15, offset: 1, calendar: mondayFirst,
                                options: MonthOptions(monthNumberStyle: .roman))
        #expect(january.title == "JANUARY")
        #expect(january.monthNumber == 1)
        #expect(january.monthNumberLabel == "I")
        #expect(january.year == 2027)

        let december = try model(2027, 1, 15, offset: -1, calendar: mondayFirst,
                                 options: MonthOptions(monthNumberStyle: .roman))
        #expect(december.title == "DECEMBER")
        #expect(december.monthNumber == 12)
        #expect(december.monthNumberLabel == "XII")
        #expect(december.year == 2026)
    }

    // Off leaves no label, but the number itself stays available to the view's
    // accessibility text.
    @Test func monthNumberLabelAbsentWhenStyleIsOff() throws {
        let august = try model(2026, 8, 12, calendar: mondayFirst)
        #expect(august.monthNumberLabel == nil)
        #expect(august.monthNumber == 8)
    }

    // MARK: - Weekends

    @Test func weekendColumnsFollowRegion() throws {
        // US, Sunday-first: first and last columns.
        #expect(try model(2026, 8, 12, calendar: sundayFirst).weekendColumns
                == [true, false, false, false, false, false, true])
        // US, Monday-first override: Saturday and Sunday move to the end.
        let mondayLayout = try model(2026, 8, 12, calendar: sundayFirst,
                                     options: MonthOptions(firstWeekday: 2))
        #expect(mondayLayout.weekendColumns
                == [false, false, false, false, false, true, true])
    }

    @Test func fridaySaturdayWeekendRegion() throws {
        // Aug 14 2026 is a Friday – weekend in Saudi Arabia, weekday in the US.
        let friday = try date(2026, 8, 14, in: fridaySaturdayWeekend)
        #expect(fridaySaturdayWeekend.isDateInWeekend(friday))
        let august = try model(2026, 8, 12, calendar: fridaySaturdayWeekend)
        // Sunday-first grid: Friday is column 6, Saturday column 7 → indices 5, 6.
        #expect(august.weekendColumns
                == [false, false, false, false, false, true, true])
    }

    // MARK: - Year label

    @Test func yearLabelFollowsTheCalendarsYearNumbering() throws {
        let reference = Date(timeIntervalSince1970: 1_787_000_000)   // Aug 2026
        let expected: [Calendar.Identifier: String] = [
            .gregorian: "\u{2019}26",
            .iso8601: "\u{2019}26",
            .buddhist: "2569",
            .japanese: "8",
            .republicOfChina: "115",
            .hebrew: "5786",
        ]

        for (identifier, label) in expected {
            let calendar = Fixtures.calendar(identifier: identifier, locale: "en_US")
            let row = monthRow(containing: reference,
                               offsets: [0],
                               showYear: true,
                               builder: MonthModelBuilder(calendar: calendar,
                                                          options: MonthOptions()))
            #expect(row.yearLabel == label, "identifier=\(identifier)")
        }
    }

    @Test func yearLabelUsesTwoDigitsWithApostrophe() throws {
        #expect(yearLabel(forYear: 2026) == "\u{2019}26")
        #expect(yearLabel(forYear: 2007) == "\u{2019}07")
        #expect(yearLabel(forYear: 2100) == "\u{2019}00")
    }

    // Non-Gregorian calendars print their year in full, but a Gregorian-style
    // year below 100 still has to pad rather than print one digit.
    @Test func yearLabelPadsYearsBelowOneHundred() throws {
        #expect(yearLabel(forYear: 7) == "\u{2019}07")
        #expect(yearLabel(forYear: 99) == "\u{2019}99")
        #expect(yearLabel(forYear: 0) == "\u{2019}00")
    }

    // MARK: - Empty rows

    // `showYear: true` is the combination that used to subscript an empty array.
    @Test func anEmptyRowBuildsNoModelsAndNoYearLabel() throws {
        let row = monthRow(containing: try date(2026, 8, 12, in: mondayFirst),
                           offsets: [],
                           showYear: true,
                           builder: MonthModelBuilder(calendar: mondayFirst,
                                                      options: MonthOptions()))

        #expect(row.models.isEmpty)
        #expect(row.yearLabel == nil)
    }

    // MARK: - Timeline dates

    @Test func timelineDatesAlignToMidnightAcrossDST() throws {
        let calendar = Fixtures.calendar(locale: "en_US", timeZone: "America/New_York")
        // Springs forward on Mar 8 2026 – both following midnights must stay 00:00.
        let beforeTransition = try Fixtures.date(2026, 3, 7, hour: 15, in: calendar)
        let dates = timelineDates(from: beforeTransition, calendar: calendar)
        #expect(dates.count == 3)
        #expect(dates[0] == beforeTransition)
        for midnight in dates.dropFirst() {
            let components = calendar.dateComponents([.hour, .minute], from: midnight)
            #expect(components.hour == 0)
            #expect(components.minute == 0)
        }
        #expect(calendar.component(.day, from: dates[1]) == 8)
        #expect(calendar.component(.day, from: dates[2]) == 9)
    }
}
