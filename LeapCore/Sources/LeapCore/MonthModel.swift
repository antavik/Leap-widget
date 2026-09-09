import Foundation

public enum MonthNumberStyle: String, CaseIterable, Sendable {
    case arabic
    case roman

    private static let romanLabels = ["I", "II", "III", "IV", "V", "VI",
                                                "VII", "VIII", "IX", "X", "XI", "XII"]

    public func label(forMonth month: Int) -> String? {
        switch self {
        case .arabic:
            return month > 0 ? String(month) : nil
        case .roman:
            return (1...12).contains(month) ? Self.romanLabels[month - 1] : nil
        }
    }
}

public struct MonthOptions: Equatable, Sendable {
    public let firstWeekday: Int?
    public let showWeekNumbers: Bool
    public let showOutsideDays: Bool
    public let monthNumberStyle: MonthNumberStyle?

    public init(firstWeekday: Int? = nil,
                showWeekNumbers: Bool = false,
                showOutsideDays: Bool = true,
                monthNumberStyle: MonthNumberStyle? = nil) {
        self.firstWeekday = firstWeekday
        self.showWeekNumbers = showWeekNumbers
        self.showOutsideDays = showOutsideDays
        self.monthNumberStyle = monthNumberStyle
    }
}

public struct Day: Equatable, Sendable {
    public let number: Int
    public let isToday: Bool
    public let isOutsideMonth: Bool

    init(number: Int, isToday: Bool, isOutsideMonth: Bool = false) {
        self.number = number
        self.isToday = isToday
        self.isOutsideMonth = isOutsideMonth
    }
}

public struct MonthModel: Equatable, Sendable {
    /// Uppercased standalone month symbol, e.g. "AUGUST".
    public let title: String
    /// Calendar year of the month — the small widget's year label follows it.
    public let year: Int
    /// Month of the year, 1…12; always set, whatever the number option is.
    public let monthNumber: Int
    /// Rendered month number, e.g. "8" or "VIII"; `nil` when the option is off.
    public let monthNumberLabel: String?
    /// Very-short standalone weekday symbols rotated to the effective first weekday.
    public let weekdayHeaders: [String]
    /// One flag per column, in display order, for the weekend days of the region.
    public let weekendColumns: [Bool]
    /// Always six 7-column rows; leading/trailing cells hold adjacent-month
    /// days marked `isOutsideMonth`.
    public let weeks: [[Day]]
    /// One number per row; `nil` when the option is off.
    public let weekNumbers: [Int]?
    /// Whether `isOutsideMonth` days are drawn; off renders their cells blank.
    public let showsOutsideDays: Bool

    init(title: String, year: Int, monthNumber: Int,
                monthNumberLabel: String? = nil,
                weekdayHeaders: [String], weekendColumns: [Bool], weeks: [[Day]],
                weekNumbers: [Int]?, showsOutsideDays: Bool = true) {
        self.title = title
        self.year = year
        self.monthNumber = monthNumber
        self.monthNumberLabel = monthNumberLabel
        self.weekdayHeaders = weekdayHeaders
        self.weekendColumns = weekendColumns
        self.weeks = weeks
        self.weekNumbers = weekNumbers
        self.showsOutsideDays = showsOutsideDays
    }
}
