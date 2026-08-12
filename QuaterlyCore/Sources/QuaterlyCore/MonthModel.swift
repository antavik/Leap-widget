import Foundation

public struct MonthOptions: Equatable, Sendable {
    /// `nil` = follow the calendar's locale; otherwise 1 = Sunday … 7 = Saturday
    /// (`Calendar` weekday convention).
    public let firstWeekday: Int?
    public let showWeekNumbers: Bool

    public init(firstWeekday: Int? = nil, showWeekNumbers: Bool = false) {
        self.firstWeekday = firstWeekday
        self.showWeekNumbers = showWeekNumbers
    }
}

public struct Day: Equatable, Sendable {
    public let number: Int
    public let isToday: Bool
    public let isWeekend: Bool

    public init(number: Int, isToday: Bool, isWeekend: Bool) {
        self.number = number
        self.isToday = isToday
        self.isWeekend = isWeekend
    }
}

public struct MonthModel: Equatable, Sendable {
    /// Uppercased standalone month symbol, e.g. "AUGUST".
    public let title: String
    /// Calendar year of the month — used for year-boundary detection between
    /// adjacent displayed months.
    public let year: Int
    /// Very-short standalone weekday symbols rotated to the effective first weekday.
    public let weekdayHeaders: [String]
    /// 7-column rows; `nil` = leading/trailing blank cell.
    public let weeks: [[Day?]]
    /// One number per row; `nil` when the option is off.
    public let weekNumbers: [Int]?

    public init(title: String, year: Int, weekdayHeaders: [String], weeks: [[Day?]], weekNumbers: [Int]?) {
        self.title = title
        self.year = year
        self.weekdayHeaders = weekdayHeaders
        self.weeks = weeks
        self.weekNumbers = weekNumbers
    }

    /// Whether each of the 7 columns holds weekend days; a column's weekday is
    /// constant across rows, so the first concrete day in it decides.
    public var weekendColumns: [Bool] {
        (0..<7).map { column in
            weeks.lazy.compactMap { $0[column] }.first?.isWeekend ?? false
        }
    }
}
