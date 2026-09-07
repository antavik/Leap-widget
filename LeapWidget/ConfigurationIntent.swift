import AppIntents
import LeapCore

enum Companion: String, AppEnum {
    case next, previous

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Second Month"
    static let caseDisplayRepresentations: [Companion: DisplayRepresentation] = [
        .next: "Next",
        .previous: "Previous",
    ]
}

/// Which month the single-month (small) widget renders, relative to today.
enum DisplayedMonth: String, AppEnum {
    case current, next, previous

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Month"
    static let caseDisplayRepresentations: [DisplayedMonth: DisplayRepresentation] = [
        .current: "Current",
        .next: "Next",
        .previous: "Previous",
    ]

    var offset: Int {
        switch self {
        case .previous: -1
        case .current: 0
        case .next: 1
        }
    }
}

enum FirstWeekday: String, AppEnum {
    case system, monday, sunday

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "First Day of Week"
    static let caseDisplayRepresentations: [FirstWeekday: DisplayRepresentation] = [
        .system: "System Default",
        .monday: "Monday",
        .sunday: "Sunday",
    ]

    var calendarWeekday: Int? {
        switch self {
        case .system: nil
        case .sunday: 1
        case .monday: 2
        }
    }
}

enum MonthNumberDisplay: String, AppEnum {
    case off, arabic, roman

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Month Number"
    static let caseDisplayRepresentations: [MonthNumberDisplay: DisplayRepresentation] = [
        .off: "Off",
        .arabic: "Number (6)",
        .roman: "Roman (VI)",
    ]

    var style: MonthNumberStyle? {
        switch self {
        case .off: nil
        case .arabic: .arabic
        case .roman: .roman
        }
    }
}

enum ClickAction: String, AppEnum {
    case appleCalendar, fantastical, googleCalendar, custom, doNothing

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Click Opens"
    static let caseDisplayRepresentations: [ClickAction: DisplayRepresentation] = [
        .appleCalendar: "Default Calendar (ical://)",
        .fantastical: "Fantastical (x-fantastical3://)",
        .googleCalendar: "Google Calendar (web)",
        .custom: "Custom URL…",
        .doNothing: "Nothing",
    ]

    var preset: ClickPreset? {
        switch self {
        case .appleCalendar: .appleCalendar
        case .fantastical: .fantastical
        case .googleCalendar: .googleCalendar
        case .custom, .doNothing: nil
        }
    }
}

enum ClickTarget {
    case preset(ClickPreset)
    case customURL(String)
    case none
}

protocol CalendarConfiguration {
    /// Months to show relative to today, in display order.
    var monthOffsets: [Int] { get }
    var firstWeekday: FirstWeekday { get }
    var showWeekNumbers: Bool { get }
    var showOutsideDays: Bool { get }
    var showYear: Bool { get }
    var monthNumber: MonthNumberDisplay { get }
    var clickAction: ClickAction { get }
    var customURL: String { get }
}

extension CalendarConfiguration {
    var clickTarget: ClickTarget {
        if let preset = clickAction.preset { return .preset(preset) }
        guard clickAction == .custom else { return .none }
        let trimmed = customURL.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? .none : .customURL(trimmed)
    }

    var monthOptions: MonthOptions {
        MonthOptions(firstWeekday: firstWeekday.calendarWeekday,
                     showWeekNumbers: showWeekNumbers,
                     showOutsideDays: showOutsideDays,
                     monthNumberStyle: monthNumber.style)
    }
}

struct CalendarConfigIntent: WidgetConfigurationIntent, CalendarConfiguration {
    static let title: LocalizedStringResource = "Calendar Options"

    @Parameter(title: "Second Month", default: .next)
    var companion: Companion

    var monthOffsets: [Int] { companion == .previous ? [-1, 0] : [0, 1] }

    @Parameter(title: "First Day of Week", default: .system)
    var firstWeekday: FirstWeekday

    @Parameter(title: "Week Numbers", default: false)
    var showWeekNumbers: Bool

    @Parameter(title: "Adjacent Month Days", default: true)
    var showOutsideDays: Bool

    @Parameter(title: "Show Current Year", default: true)
    var showYear: Bool

    @Parameter(title: "Month Number", default: .off)
    var monthNumber: MonthNumberDisplay

    @Parameter(title: "Click Opens", default: .appleCalendar)
    var clickAction: ClickAction

    @Parameter(title: "Custom URL", default: "")
    var customURL: String

    static var parameterSummary: some ParameterSummary {
        When(\CalendarConfigIntent.$clickAction, .equalTo, .custom) {
            Summary("Show current and \(\.$companion) month") {
                \.$firstWeekday
                \.$showWeekNumbers
                \.$showOutsideDays
                \.$showYear
                \.$monthNumber
                \.$clickAction
                \.$customURL
            }
        } otherwise: {
            Summary("Show current and \(\.$companion) month") {
                \.$firstWeekday
                \.$showWeekNumbers
                \.$showOutsideDays
                \.$showYear
                \.$monthNumber
                \.$clickAction
            }
        }
    }
}

struct SmallCalendarConfigIntent: WidgetConfigurationIntent, CalendarConfiguration {
    static let title: LocalizedStringResource = "Calendar Options"

    @Parameter(title: "Month", default: .current)
    var month: DisplayedMonth

    var monthOffsets: [Int] { [month.offset] }

    @Parameter(title: "First Day of Week", default: .system)
    var firstWeekday: FirstWeekday

    @Parameter(title: "Week Numbers", default: false)
    var showWeekNumbers: Bool

    @Parameter(title: "Adjacent Month Days", default: true)
    var showOutsideDays: Bool

    @Parameter(title: "Show Year", default: true)
    var showYear: Bool

    @Parameter(title: "Month Number", default: .off)
    var monthNumber: MonthNumberDisplay

    @Parameter(title: "Click Opens", default: .appleCalendar)
    var clickAction: ClickAction

    @Parameter(title: "Custom URL", default: "")
    var customURL: String

    static var parameterSummary: some ParameterSummary {
        When(\SmallCalendarConfigIntent.$clickAction, .equalTo, .custom) {
            Summary("Show the \(\.$month) month") {
                \.$firstWeekday
                \.$showWeekNumbers
                \.$showOutsideDays
                \.$showYear
                \.$monthNumber
                \.$clickAction
                \.$customURL
            }
        } otherwise: {
            Summary("Show the \(\.$month) month") {
                \.$firstWeekday
                \.$showWeekNumbers
                \.$showOutsideDays
                \.$showYear
                \.$monthNumber
                \.$clickAction
            }
        }
    }
}
