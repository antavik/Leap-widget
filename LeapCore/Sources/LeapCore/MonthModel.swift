import Foundation

public struct MonthOptions: Equatable, Sendable {
    /// `nil` = follow the calendar's locale; otherwise 1 = Sunday … 7 = Saturday
    /// (`Calendar` weekday convention).
    public let firstWeekday: Int?
    public let showWeekNumbers: Bool
    public let showOutsideDays: Bool

    public init(firstWeekday: Int? = nil,
                showWeekNumbers: Bool = false,
                showOutsideDays: Bool = true) {
        self.firstWeekday = firstWeekday
        self.showWeekNumbers = showWeekNumbers
        self.showOutsideDays = showOutsideDays
    }
}

public struct Day: Equatable, Sendable {
    public let number: Int
    public let isToday: Bool
    public let isWeekend: Bool
    public let isOutsideMonth: Bool

    public init(number: Int, isToday: Bool, isWeekend: Bool, isOutsideMonth: Bool = false) {
        self.number = number
        self.isToday = isToday
        self.isWeekend = isWeekend
        self.isOutsideMonth = isOutsideMonth
    }
}

public struct MonthModel: Equatable, Sendable {
    /// Uppercased standalone month symbol, e.g. "AUGUST".
    public let title: String
    /// Calendar year of the month — the small widget's year label follows it.
    public let year: Int
    /// Very-short standalone weekday symbols rotated to the effective first weekday.
    public let weekdayHeaders: [String]
    /// Always six 7-column rows; leading/trailing cells hold adjacent-month
    /// days marked `isOutsideMonth`.
    public let weeks: [[Day]]
    /// One number per row; `nil` when the option is off.
    public let weekNumbers: [Int]?
    /// Whether `isOutsideMonth` days are drawn; off renders their cells blank.
    public let showsOutsideDays: Bool

    public init(title: String, year: Int, weekdayHeaders: [String], weeks: [[Day]],
                weekNumbers: [Int]?, showsOutsideDays: Bool = true) {
        self.title = title
        self.year = year
        self.weekdayHeaders = weekdayHeaders
        self.weeks = weeks
        self.weekNumbers = weekNumbers
        self.showsOutsideDays = showsOutsideDays
    }

    public var weekendColumns: [Bool] {
        (0..<7).map { column in
            weeks.first?[column].isWeekend ?? false
        }
    }
}
