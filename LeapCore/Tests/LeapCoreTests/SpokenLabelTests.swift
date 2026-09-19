import Testing
import Foundation
@testable import LeapCore

/// A plain string built in `MonthModelBuilder`, so it tests like the rest of
/// the model — no view, no accessibility harness. Most of these assert
/// `spokenSummary` in `CalendarMath.swift`; only the row three reach
/// `MonthRow.swift`.
@Suite("Spoken labels")
struct SpokenLabelTests {
    private let usSundayFirst = Fixtures.sundayFirst
    private let ukMondayFirst = Fixtures.mondayFirst
    private let germanMondayFirst = Fixtures.germanMondayFirst

    private func summary(_ year: Int, _ month: Int, _ day: Int,
                         offset: Int = 0,
                         calendar: Calendar,
                         options: MonthOptions = MonthOptions()) throws -> String {
        let today = try Fixtures.date(year, month, day, in: calendar)

        return monthModel(containing: today, offset: offset, calendar: calendar,
                          today: today, options: options).spokenSummary
    }

    // MARK: - The month holding today

    @Test func monthHoldingTodaySpeaksTheDate() throws {
        #expect(try summary(2026, 9, 15, calendar: usSundayFirst)
                == "Today is Tuesday, September 15, 2026")
    }

    @Test func spokenDateFollowsTheLocalesDateOrder() throws {
        // en_GB puts the day first; the format style carries that, so the
        // string is never assembled by hand.
        #expect(try summary(2026, 9, 15, calendar: ukMondayFirst)
                == "Today is Tuesday, 15 September 2026")
    }

    @Test func spokenDateUsesTheLocalesOwnMonthAndWeekdayNames() throws {
        let spoken = try summary(2026, 9, 15, calendar: germanMondayFirst)

        #expect(spoken.contains("Dienstag"))
        #expect(spoken.contains("September"))
        #expect(spoken.contains("2026"))
    }

    /// Hard-coded: computing the week with the same `component(.weekOfYear:)`
    /// call the builder uses would make this unable to fail. Tue 15 Sep 2026 is
    /// week 38 under ISO and US rules alike.
    @Test(arguments: [(Fixtures.mondayFirst, 38), (Fixtures.sundayFirst, 38)])
    func weekNumberJoinsTheDateOnlyWhenTheColumnIsShown(calendar: Calendar,
                                                        week: Int) throws {
        let options = MonthOptions(showWeekNumbers: true)

        #expect(try summary(2026, 9, 15, calendar: calendar, options: options)
                .hasSuffix(", week \(week)"))
        #expect(try !summary(2026, 9, 15, calendar: calendar).contains("week"))
    }

    // MARK: - Months that do not hold today

    @Test func otherMonthsSpeakTheirOwnMonthAndYear() throws {
        #expect(try summary(2026, 9, 15, offset: 1, calendar: usSundayFirst)
                == "October 2026")
        #expect(try summary(2026, 9, 15, offset: -1, calendar: usSundayFirst)
                == "August 2026")
    }

    @Test func aMonthAcrossTheYearBoundaryNamesItsOwnYear() throws {
        #expect(try summary(2027, 1, 10, offset: -1, calendar: usSundayFirst)
                == "December 2026")
        #expect(try summary(2026, 12, 10, offset: 1, calendar: usSundayFirst)
                == "January 2027")
    }

    @Test func otherMonthsNeverSpeakTodayEvenWithWeekNumbersOn() throws {
        let spoken = try summary(2026, 9, 15, offset: 1, calendar: usSundayFirst,
                                 options: MonthOptions(showWeekNumbers: true))

        #expect(spoken == "October 2026")
    }

    // MARK: - Options that must not move the string

    @Test func layoutOptionsDoNotChangeWhatIsSpoken() throws {
        let reference = try summary(2026, 9, 15, calendar: usSundayFirst)

        // These change the grid, not the answer to "what is today".
        #expect(try summary(2026, 9, 15, calendar: usSundayFirst,
                            options: MonthOptions(firstWeekday: 2,
                                                  showOutsideDays: false))
                == reference)
        #expect(try summary(2026, 9, 15, calendar: usSundayFirst,
                            options: MonthOptions(monthNumberStyle: .roman))
                == reference)
    }

    // MARK: - Which month the widget speaks

    @Test func onlyTheOffsetZeroMonthContainsToday() throws {
        let today = try Fixtures.date(2026, 9, 15, in: usSundayFirst)
        let builder = MonthModelBuilder(calendar: usSundayFirst, options: MonthOptions())
        let months = (-1...1).map {
            builder.model(containing: today, offset: $0, today: today)
        }

        #expect(months.map(\.containsToday) == [false, true, false])
    }

    // MARK: - The whole row

    private func rowSummary(_ year: Int, _ month: Int, _ day: Int,
                            offsets: [Int],
                            calendar: Calendar,
                            options: MonthOptions = MonthOptions()) throws -> String {
        let today = try Fixtures.date(year, month, day, in: calendar)
        let row = monthRow(containing: today, offsets: offsets, showYear: true,
                           builder: MonthModelBuilder(calendar: calendar,
                                                      options: options))

        return spokenSummary(of: row.models,
                             locale: calendar.locale ?? .autoupdatingCurrent)
    }

    @Test func aTwoMonthRowNamesOnlyTheMonthHoldingToday() throws {
        #expect(try rowSummary(2026, 9, 15, offsets: [0, 1], calendar: usSundayFirst)
                == "Today is Tuesday, September 15, 2026")
        #expect(try rowSummary(2026, 9, 15, offsets: [-1, 0], calendar: usSundayFirst)
                == "Today is Tuesday, September 15, 2026")
    }

    @Test func aSingleMonthRowSpeaksThatMonthAlone() throws {
        #expect(try rowSummary(2026, 9, 15, offsets: [1], calendar: usSundayFirst)
                == "October 2026")
    }

    @Test func anEmptyRowSpeaksNothing() throws {
        let locale = try #require(usSundayFirst.locale)
        #expect(spokenSummary(of: [], locale: locale).isEmpty)
    }
}
