import Testing
import Foundation
@testable import LeapCore

/// The spoken month label is a plain string built in `MonthModelBuilder`, so
/// it tests like the rest of the model — no view, no accessibility harness.
private func makeCalendar(locale: String, firstWeekday: Int,
                          minimumDaysInFirstWeek: Int) -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.locale = Locale(identifier: locale)
    calendar.firstWeekday = firstWeekday
    calendar.minimumDaysInFirstWeek = minimumDaysInFirstWeek
    calendar.timeZone = TimeZone(identifier: "GMT")!
    return calendar
}

private let usSundayFirst = makeCalendar(locale: "en_US", firstWeekday: 1,
                                         minimumDaysInFirstWeek: 1)
private let ukMondayFirst = makeCalendar(locale: "en_GB", firstWeekday: 2,
                                         minimumDaysInFirstWeek: 4)
private let germanMondayFirst = makeCalendar(locale: "de_DE", firstWeekday: 2,
                                             minimumDaysInFirstWeek: 4)

private func date(_ year: Int, _ month: Int, _ day: Int, in calendar: Calendar) -> Date {
    calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
}

private func summary(_ year: Int, _ month: Int, _ day: Int,
                     offset: Int = 0,
                     calendar: Calendar,
                     options: MonthOptions = MonthOptions()) -> String {
    let today = date(year, month, day, in: calendar)

    return monthModel(containing: today, offset: offset, calendar: calendar,
                      today: today, options: options).spokenSummary
}

// MARK: - The month holding today

@Test func monthHoldingTodaySpeaksTheDate() {
    #expect(summary(2026, 9, 15, calendar: usSundayFirst)
            == "Today is Tuesday, September 15, 2026")
}

@Test func spokenDateFollowsTheLocalesDateOrder() {
    // en_GB puts the day before the month; the format style carries that, so
    // the string is never assembled by hand.
    #expect(summary(2026, 9, 15, calendar: ukMondayFirst)
            == "Today is Tuesday, 15 September 2026")
}

@Test func spokenDateUsesTheLocalesOwnMonthAndWeekdayNames() {
    let spoken = summary(2026, 9, 15, calendar: germanMondayFirst)

    #expect(spoken.contains("Dienstag"))
    #expect(spoken.contains("September"))
    #expect(spoken.contains("2026"))
}

@Test func weekNumberJoinsTheDateOnlyWhenTheColumnIsShown() {
    let options = MonthOptions(showWeekNumbers: true)
    let week = ukMondayFirst.component(.weekOfYear,
                                       from: date(2026, 9, 15, in: ukMondayFirst))

    #expect(summary(2026, 9, 15, calendar: ukMondayFirst, options: options)
            .hasSuffix(", week \(week)"))
    #expect(!summary(2026, 9, 15, calendar: ukMondayFirst).contains("week"))
}

@Test func usWeekNumberingIsSpokenForSundayFirstRegions() {
    let options = MonthOptions(showWeekNumbers: true)
    let week = usSundayFirst.component(.weekOfYear,
                                       from: date(2026, 9, 15, in: usSundayFirst))

    #expect(summary(2026, 9, 15, calendar: usSundayFirst, options: options)
            .hasSuffix(", week \(week)"))
}

// MARK: - Months that do not hold today

@Test func otherMonthsSpeakTheirOwnMonthAndYear() {
    #expect(summary(2026, 9, 15, offset: 1, calendar: usSundayFirst) == "October 2026")
    #expect(summary(2026, 9, 15, offset: -1, calendar: usSundayFirst) == "August 2026")
}

@Test func aMonthAcrossTheYearBoundaryNamesItsOwnYear() {
    #expect(summary(2027, 1, 10, offset: -1, calendar: usSundayFirst) == "December 2026")
    #expect(summary(2026, 12, 10, offset: 1, calendar: usSundayFirst) == "January 2027")
}

@Test func otherMonthsNeverSpeakTodayEvenWithWeekNumbersOn() {
    let spoken = summary(2026, 9, 15, offset: 1, calendar: usSundayFirst,
                         options: MonthOptions(showWeekNumbers: true))

    #expect(spoken == "October 2026")
}

// MARK: - Options that must not move the string

@Test func layoutOptionsDoNotChangeWhatIsSpoken() {
    let reference = summary(2026, 9, 15, calendar: usSundayFirst)

    // Hidden adjacent-month days and a different first weekday change the grid,
    // not the answer to "what is today".
    #expect(summary(2026, 9, 15, calendar: usSundayFirst,
                    options: MonthOptions(firstWeekday: 2, showOutsideDays: false))
            == reference)
    #expect(summary(2026, 9, 15, calendar: usSundayFirst,
                    options: MonthOptions(monthNumberStyle: .roman)) == reference)
}

// MARK: - Which month the widget speaks

@Test func onlyTheOffsetZeroMonthContainsToday() {
    let today = date(2026, 9, 15, in: usSundayFirst)
    let builder = MonthModelBuilder(calendar: usSundayFirst, options: MonthOptions())
    let months = (-1...1).map {
        builder.model(containing: today, offset: $0, today: today)
    }

    #expect(months.map(\.containsToday) == [false, true, false])
}

@Test func noMonthContainsTodayWhenTheWidgetShowsANeighbour() {
    let today = date(2026, 9, 15, in: usSundayFirst)
    let builder = MonthModelBuilder(calendar: usSundayFirst, options: MonthOptions())
    let month = builder.model(containing: today, offset: 1, today: today)

    #expect(!month.containsToday)
    #expect(month.spokenSummary == "October 2026")
}
