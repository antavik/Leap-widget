import XCTest
@testable import QuaterlyCore

/// Budget checks for §4.11 — XCTest `measure`, since Swift Testing has no
/// measurement API (§5).
final class PerformanceTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US")
        calendar.firstWeekday = 2
        calendar.timeZone = TimeZone(identifier: "GMT")!
        return calendar
    }

    /// Full 3-month build with week numbers — must sit far below the 50 ms
    /// per-reload budget.
    func testThreeMonthModelBuild() {
        let calendar = self.calendar
        let today = calendar.date(from: DateComponents(year: 2026, month: 8, day: 12))!
        let options = MonthOptions(firstWeekday: 2, showWeekNumbers: true)
        measure(metrics: [XCTClockMetric(), XCTMemoryMetric()]) {
            for _ in 0..<10 {
                for offset in -1...1 {
                    _ = monthModel(containing: today, offset: offset,
                                   calendar: calendar, today: today, options: options)
                }
            }
        }
    }

    func testTimelineDatesBuild() {
        let calendar = self.calendar
        let now = calendar.date(from: DateComponents(year: 2026, month: 8, day: 12, hour: 9))!
        measure {
            for _ in 0..<100 {
                _ = timelineDates(from: now, calendar: calendar)
            }
        }
    }
}
