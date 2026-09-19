import Testing
import Foundation
@testable import LeapCore

@Suite("Month number style")
struct MonthNumberStyleTests {
    @Test func monthNumberStyleRawValuesAreStable() {
        #expect(MonthNumberStyle.arabic.rawValue == "arabic")
        #expect(MonthNumberStyle.roman.rawValue == "roman")
        #expect(MonthNumberStyle(rawValue: "roman") == .roman)
        #expect(MonthNumberStyle(rawValue: "greek") == nil)
        #expect(MonthNumberStyle.allCases.count == 2)
    }

    @Test func arabicLabelsCoverEveryMonth() {
        let expected = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12"]
        #expect((1...12).map { MonthNumberStyle.arabic.label(forMonth: $0) } == expected)
    }

    /// Parsed back rather than restated: repeating the implementation's own
    /// `romanLabels` array would assert that the array equals itself.
    @Test func romanLabelsParseBackToTheirMonth() throws {
        for month in 1...12 {
            let label = try #require(MonthNumberStyle.roman.label(forMonth: month))
            #expect(Self.arabicValue(ofRoman: label) == month,
                    "month=\(month) label=\(label)")
        }
    }

    private static func arabicValue(ofRoman label: String) -> Int {
        let values: [Character: Int] = ["I": 1, "V": 5, "X": 10]
        var total = 0
        var previous = 0

        for character in label.reversed() {
            let value = values[character] ?? 0
            total += value < previous ? -value : value
            previous = max(previous, value)
        }

        return total
    }

    @Test func labelsOutsideTheRomanTableAreNil() {
        #expect(MonthNumberStyle.roman.label(forMonth: 13) == nil)
        #expect(MonthNumberStyle.roman.label(forMonth: 0) == nil)
        #expect(MonthNumberStyle.arabic.label(forMonth: 13) == "13")
        #expect(MonthNumberStyle.arabic.label(forMonth: 0) == nil)
    }

    @Test func septemberIsSpelledIXInAMonthModel() throws {
        let calendar = Fixtures.mondayFirst
        let september = try Fixtures.date(2026, 9, 12, in: calendar)
        let model = monthModel(containing: september, offset: 0, calendar: calendar,
                               today: september,
                               options: MonthOptions(showWeekNumbers: true,
                                                     monthNumberStyle: .roman))

        #expect(model.monthNumberLabel == "IX")
        #expect(model.monthNumber == 9)
    }
}
