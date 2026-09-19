import Foundation

public enum DisplayedMonth: String, CaseIterable, Sendable {
    case current, next, previous

    public var offset: Int {
        switch self {
        case .previous: -1
        case .current: 0
        case .next: 1
        }
    }

    public var monthOffsets: [Int] { [offset] }
}

public enum Companion: String, CaseIterable, Sendable {
    case next, previous

    /// Display order, so `previous` puts the current month second.
    public var monthOffsets: [Int] {
        switch self {
        case .next: [0, 1]
        case .previous: [-1, 0]
        }
    }
}

public enum FirstWeekday: String, CaseIterable, Sendable {
    case system, monday, sunday

    public var calendarWeekday: Int? {
        switch self {
        case .system: nil
        case .sunday: 1
        case .monday: 2
        }
    }
}

public enum MonthNumberDisplay: String, CaseIterable, Sendable {
    case off, arabic, roman

    public var style: MonthNumberStyle? {
        switch self {
        case .off: nil
        case .arabic: .arabic
        case .roman: .roman
        }
    }
}

public enum ClickAction: String, CaseIterable, Sendable {
    case appleCalendar, fantastical, googleCalendar, doNothing

    public var preset: ClickPreset? {
        switch self {
        case .appleCalendar: .appleCalendar
        case .fantastical: .fantastical
        case .googleCalendar: .googleCalendar
        case .doNothing: nil
        }
    }
}

public struct CalendarSettings: Equatable, Sendable {
    public let monthOffsets: [Int]
    public let firstWeekday: FirstWeekday
    public let showWeekNumbers: Bool
    public let showOutsideDays: Bool
    public let showYear: Bool
    public let monthNumber: MonthNumberDisplay
    public let clickAction: ClickAction

    public init(monthOffsets: [Int],
                firstWeekday: FirstWeekday = .system,
                showWeekNumbers: Bool = false,
                showOutsideDays: Bool = true,
                showYear: Bool = true,
                monthNumber: MonthNumberDisplay = .off,
                clickAction: ClickAction = .appleCalendar) {
        self.monthOffsets = monthOffsets
        self.firstWeekday = firstWeekday
        self.showWeekNumbers = showWeekNumbers
        self.showOutsideDays = showOutsideDays
        self.showYear = showYear
        self.monthNumber = monthNumber
        self.clickAction = clickAction
    }

    public var monthOptions: MonthOptions {
        MonthOptions(firstWeekday: firstWeekday.calendarWeekday,
                     showWeekNumbers: showWeekNumbers,
                     showOutsideDays: showOutsideDays,
                     monthNumberStyle: monthNumber.style)
    }

    public var clickPreset: ClickPreset? { clickAction.preset }
}

public protocol CalendarConfiguration {
    var settings: CalendarSettings { get }
}
