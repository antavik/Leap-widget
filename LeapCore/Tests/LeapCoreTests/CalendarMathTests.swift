import Testing
import Foundation
@testable import LeapCore

private func makeCalendar(locale: String,
                          firstWeekday: Int,
                          minimumDaysInFirstWeek: Int,
                          timeZone: String = "GMT") -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.locale = Locale(identifier: locale)
    calendar.firstWeekday = firstWeekday
    calendar.minimumDaysInFirstWeek = minimumDaysInFirstWeek
    calendar.timeZone = TimeZone(identifier: timeZone)!
    return calendar
}

/// Monday-first, ISO week rules (UK-style region).
private let mondayFirst = makeCalendar(locale: "en_GB", firstWeekday: 2, minimumDaysInFirstWeek: 4)
/// Sunday-first, US week rules.
private let sundayFirst = makeCalendar(locale: "en_US", firstWeekday: 1, minimumDaysInFirstWeek: 1)
/// Friday–Saturday weekend region.
private let fridaySaturdayWeekend = makeCalendar(locale: "ar_SA", firstWeekday: 1, minimumDaysInFirstWeek: 1)

private func date(_ year: Int, _ month: Int, _ day: Int, in calendar: Calendar) -> Date {
    calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
}

private func model(_ year: Int, _ month: Int, _ day: Int,
                   offset: Int = 0,
                   calendar: Calendar,
                   options: MonthOptions = MonthOptions()) -> MonthModel {
    let reference = date(year, month, day, in: calendar)
    return monthModel(containing: reference,
                      offset: offset,
                      calendar: calendar,
                      today: reference,
                      options: options)
}

// MARK: - Grid layout

@Test func augustMondayFirstHasSixRows() throws {
    let august = model(2026, 8, 12, calendar: mondayFirst)
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
    let august = model(2026, 8, 12, calendar: sundayFirst)
    #expect(august.weeks.count == 6)
    // Sunday-first: Saturday Aug 1 lands in the last column, after six July days.
    #expect(august.weeks[0].prefix(6).allSatisfy { $0.isOutsideMonth })
    #expect(august.weeks[0][6].number == 1)
    #expect(august.weeks[0][6].isOutsideMonth == false)
}

@Test func shortMonthsStillFillSixRows() throws {
    // Feb 2026 starts on Sunday and has 28 days → 4 exact rows Sunday-first,
    // so the last two rows are entirely March.
    let february = model(2026, 2, 10, calendar: sundayFirst)
    #expect(february.weeks.count == 6)
    #expect(february.weeks[3][6].number == 28)
    #expect(february.weeks[3][6].isOutsideMonth == false)
    #expect(february.weeks[4].allSatisfy { $0.isOutsideMonth })
    #expect(february.weeks[5].allSatisfy { $0.isOutsideMonth })
    #expect(february.weeks[4].map(\.number) == [1, 2, 3, 4, 5, 6, 7])

    // Leap Feb 2024 (starts Thursday, 29 days) ends mid-row Monday-first.
    let leap = model(2024, 2, 10, calendar: mondayFirst)
    #expect(leap.weeks.count == 6)
    #expect(leap.weeks[4][3].number == 29)
    #expect(leap.weeks[4][3].isOutsideMonth == false)
    #expect(leap.weeks[4][4].number == 1)
    #expect(leap.weeks[4][4].isOutsideMonth)
}

@Test func outsideDaysToggleReachesModel() throws {
    #expect(model(2026, 8, 12, calendar: mondayFirst).showsOutsideDays)
    let hidden = model(2026, 8, 12, calendar: mondayFirst,
                       options: MonthOptions(showOutsideDays: false))
    #expect(hidden.showsOutsideDays == false)
    // The grid data itself stays complete either way — hiding is a render concern.
    #expect(hidden.weeks.count == 6)
    #expect(hidden.weeks[0].prefix(5).allSatisfy { $0.isOutsideMonth })
}

@Test func headerRotationMatchesLayoutForEveryOverride() throws {
    let symbols = mondayFirst.veryShortStandaloneWeekdaySymbols
    for override in 1...7 {
        let options = MonthOptions(firstWeekday: override)
        let august = model(2026, 8, 12, calendar: sundayFirst, options: options)
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

// MARK: - Today marker

@Test func todayMarkedOnlyInCurrentMonth() throws {
    let reference = date(2026, 8, 12, in: mondayFirst)
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
    // Today Aug 1 2026 appears as a trailing day in July's grid — no marker there.
    let july = date(2026, 7, 15, in: mondayFirst)
    let today = date(2026, 8, 1, in: mondayFirst)
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
        let displayed = model(2026, 8, 12, offset: offset,
                              calendar: mondayFirst, options: options)
        #expect(displayed.monthNumber == expected)
        #expect(displayed.monthNumberLabel == String(expected))
    }
}

// The one place number and year disagree: December + 1 is month 1 of the
// next year; titles and years must follow the displayed month across it.
@Test func monthNumberWrapsAcrossTheYearBoundary() throws {
    let january = model(2026, 12, 15, offset: 1, calendar: mondayFirst,
                        options: MonthOptions(monthNumberStyle: .roman))
    #expect(january.title == "JANUARY")
    #expect(january.monthNumber == 1)
    #expect(january.monthNumberLabel == "I")
    #expect(january.year == 2027)

    let december = model(2027, 1, 15, offset: -1, calendar: mondayFirst,
                         options: MonthOptions(monthNumberStyle: .roman))
    #expect(december.title == "DECEMBER")
    #expect(december.monthNumber == 12)
    #expect(december.monthNumberLabel == "XII")
    #expect(december.year == 2026)
}

// Off leaves no label, but the number itself stays available to the view's
// accessibility text.
@Test func monthNumberLabelAbsentWhenStyleIsOff() throws {
    let august = model(2026, 8, 12, calendar: mondayFirst)
    #expect(august.monthNumberLabel == nil)
    #expect(august.monthNumber == 8)
}

// MARK: - Weekends

@Test func weekendColumnsFollowRegion() throws {
    // US, Sunday-first: first and last columns.
    #expect(model(2026, 8, 12, calendar: sundayFirst).weekendColumns
            == [true, false, false, false, false, false, true])
    // US, Monday-first override: Saturday and Sunday move to the end.
    let mondayLayout = model(2026, 8, 12, calendar: sundayFirst,
                             options: MonthOptions(firstWeekday: 2))
    #expect(mondayLayout.weekendColumns
            == [false, false, false, false, false, true, true])
}

@Test func fridaySaturdayWeekendRegion() throws {
    // Aug 14 2026 is a Friday — weekend in Saudi Arabia, weekday in the US.
    let friday = date(2026, 8, 14, in: fridaySaturdayWeekend)
    #expect(fridaySaturdayWeekend.isDateInWeekend(friday))
    let august = model(2026, 8, 12, calendar: fridaySaturdayWeekend)
    // Sunday-first grid: Friday is column 6, Saturday column 7 → indices 5, 6.
    #expect(august.weekendColumns
            == [false, false, false, false, false, true, true])
}

// MARK: - Week numbers

@Test func isoWeekNumbersMondayFirst() throws {
    // 2026 is an ISO W53 year; December's last in-month row starts Mon Dec 28,
    // and the trailing all-January row already carries W1 of 2027.
    let december = model(2026, 12, 15, calendar: mondayFirst,
                         options: MonthOptions(showWeekNumbers: true))
    #expect(december.weekNumbers == [49, 50, 51, 52, 53, 1])
    // January 2027's first row still belongs to ISO week 53 of 2026; W1 starts
    // Monday Jan 4.
    let january = model(2027, 1, 10, calendar: mondayFirst,
                        options: MonthOptions(showWeekNumbers: true))
    #expect(january.weekNumbers?.first == 53)
    #expect(january.weekNumbers?[1] == 1)
}

@Test func usWeekNumbersSundayFirst() throws {
    // US numbering: the week of Sun Dec 27 2026 contains Jan 1 → already week 1;
    // the trailing all-January row is week 2.
    let december = model(2026, 12, 15, calendar: sundayFirst,
                         options: MonthOptions(showWeekNumbers: true))
    #expect(december.weekNumbers?[4] == 1)
    #expect(december.weekNumbers?.last == 2)
    let january = model(2027, 1, 10, calendar: sundayFirst,
                        options: MonthOptions(showWeekNumbers: true))
    #expect(january.weekNumbers?.first == 1)
}

@Test func mondayOverrideForcesISONumbering() throws {
    // A US calendar (minimumDaysInFirstWeek = 1) with a Monday override must
    // switch to ISO numbering: Jan 1–3 2027 stay in week 53 of 2026.
    let january = model(2027, 1, 10, calendar: sundayFirst,
                        options: MonthOptions(firstWeekday: 2, showWeekNumbers: true))
    #expect(january.weekNumbers?.first == 53)
    #expect(january.weekNumbers?[1] == 1)
}

@Test func weekNumbersAbsentWhenDisabled() throws {
    #expect(model(2026, 8, 12, calendar: mondayFirst).weekNumbers == nil)
}

// MARK: - Displayed offsets (span ↔ capacity)

@Test func displayedOffsetsClampToCapacity() throws {
    #expect(displayedOffsets(span: 1, companionPrevious: false, capacity: 1) == [0])
    #expect(displayedOffsets(span: 2, companionPrevious: true, capacity: 2) == [-1, 0])
    #expect(displayedOffsets(span: 2, companionPrevious: false, capacity: 2) == [0, 1])
    #expect(displayedOffsets(span: 3, companionPrevious: false, capacity: 3) == [-1, 0, 1])
    // Clamping keeps the current month, dropping the past before the future.
    #expect(displayedOffsets(span: 3, companionPrevious: false, capacity: 2) == [0, 1])
    #expect(displayedOffsets(span: 3, companionPrevious: false, capacity: 1) == [0])
    #expect(displayedOffsets(span: 2, companionPrevious: true, capacity: 1) == [0])
}

@Test func yearLabelUsesTwoDigitsWithApostrophe() throws {
    #expect(yearLabel(forYear: 2026) == "\u{2019}26")
    #expect(yearLabel(forYear: 2007) == "\u{2019}07")
    #expect(yearLabel(forYear: 2100) == "\u{2019}00")
}

// MARK: - Timeline dates (§4.6)

@Test func timelineDatesAlignToMidnightAcrossDST() throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.locale = Locale(identifier: "en_US")
    calendar.timeZone = TimeZone(identifier: "America/New_York")!
    // Springs forward on Mar 8 2026 — both following midnights must stay 00:00.
    let beforeTransition = calendar.date(
        from: DateComponents(year: 2026, month: 3, day: 7, hour: 15, minute: 30))!
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
