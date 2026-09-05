import Testing
@testable import LeapCore

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

@Test func romanLabelsCoverEveryMonth() {
    let expected = ["I", "II", "III", "IV", "V", "VI",
                    "VII", "VIII", "IX", "X", "XI", "XII"]
    #expect((1...12).map { MonthNumberStyle.roman.label(forMonth: $0) } == expected)
}

@Test func labelsOutsideTheRomanTableAreNil() {
    #expect(MonthNumberStyle.roman.label(forMonth: 13) == nil)
    #expect(MonthNumberStyle.roman.label(forMonth: 0) == nil)
    #expect(MonthNumberStyle.arabic.label(forMonth: 13) == "13")
    #expect(MonthNumberStyle.arabic.label(forMonth: 0) == nil)
}
