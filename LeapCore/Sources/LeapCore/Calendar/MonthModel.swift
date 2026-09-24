import Foundation

public struct MonthModel: Equatable, Sendable {
    /// Uppercased standalone month symbol, e.g. "AUGUST".
    public let title: String
    /// Calendar year of the month – the small widget's year label follows it.
    public let year: Int
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
    /// Whether `today` falls inside this month.
    public let containsToday: Bool
    /// The whole month spoken as one VoiceOver label: today's date when this
    /// month holds today, the month and year otherwise. Already localized.
    public let spokenSummary: String

    init(title: String, year: Int,
         monthNumberLabel: String? = nil,
         weekdayHeaders: [String], weekendColumns: [Bool], weeks: [[Day]],
         weekNumbers: [Int]?, showsOutsideDays: Bool = true,
         containsToday: Bool, spokenSummary: String) {
        self.title = title
        self.year = year
        self.monthNumberLabel = monthNumberLabel
        self.weekdayHeaders = weekdayHeaders
        self.weekendColumns = weekendColumns
        self.weeks = weeks
        self.weekNumbers = weekNumbers
        self.showsOutsideDays = showsOutsideDays
        self.containsToday = containsToday
        self.spokenSummary = spokenSummary
    }
}
