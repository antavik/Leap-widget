import Testing
import Foundation
@testable import LeapCore

/// Budget checks for §4.11. Clock budgets are hard assertions so CI fails on
/// regression; XCTest `measure` has no stored baselines and would never fail.
private func budgetCalendar() -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.locale = Locale(identifier: "en_US")
    calendar.firstWeekday = 2
    calendar.timeZone = TimeZone(identifier: "GMT")!
    return calendar
}

/// Full 3-month build with week numbers – allows 50 ms per reload; the
/// average build must sit far below it even on slow CI hosts.
@Test func threeMonthModelBuildMeetsClockBudget() {
    let calendar = budgetCalendar()
    let today = calendar.date(from: DateComponents(year: 2026, month: 8, day: 12))!
    let options = MonthOptions(firstWeekday: 2, showWeekNumbers: true)

    // Warm ICU/locale caches so the assertion measures steady-state cost.
    for offset in -1...1 {
        _ = monthModel(containing: today, offset: offset,
                       calendar: calendar, today: today, options: options)
    }

    let runs = 10
    let elapsed = ContinuousClock().measure {
        for _ in 0..<runs {
            for offset in -1...1 {
                _ = monthModel(containing: today, offset: offset,
                               calendar: calendar, today: today, options: options)
            }
        }
    }
    #expect(elapsed / runs < .milliseconds(50))
}

/// Steady-state arithmetic path with one builder reused across the reload.
/// The tight budget catches regressions to per-month ICU work.
@Test func builderThreeMonthBuildMeetsClockBudget() {
    let calendar = budgetCalendar()
    let today = calendar.date(from: DateComponents(year: 2026, month: 8, day: 12))!
    // Month numbers on: a table lookup per month must not move the budget.
    let options = MonthOptions(firstWeekday: 2, showWeekNumbers: true,
                               monthNumberStyle: .roman)
    let builder = MonthModelBuilder(calendar: calendar, options: options)

    for offset in -1...1 {   // warm-up
        _ = builder.model(containing: today, offset: offset, today: today)
    }

    let runs = 100
    let elapsed = ContinuousClock().measure {
        for _ in 0..<runs {
            for offset in -1...1 {
                _ = builder.model(containing: today, offset: offset, today: today)
            }
        }
    }
    #expect(elapsed / runs < .milliseconds(1))
}
