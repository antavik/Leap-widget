import Foundation

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
