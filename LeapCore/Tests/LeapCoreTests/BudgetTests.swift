import Testing
import Foundation
@testable import LeapCore

@Suite("Budgets",
       .disabled(if: ProcessInfo.processInfo.environment["LEAP_BUDGETS"] == nil,
                 "opt in with LEAP_BUDGETS=1"))
struct BudgetTests {
    @Test func builderThreeMonthBuildMeetsClockBudget() throws {
        let calendar = Fixtures.calendar(locale: "en_US", firstWeekday: 2)
        let today = try Fixtures.date(2026, 8, 12, in: calendar)
        // Month numbers on: a per-month table lookup must not move the budget.
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
}
