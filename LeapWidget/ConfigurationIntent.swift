import AppIntents
import LeapCore

// Case lists and display names only; every mapping lives in
// `LeapCore.CalendarSettings`. Each is the twin of a plain enum in
// `LeapCore.WidgetOptions`, bridged by raw value through `coreOption` – see that
// file for why. `scripts/check-widget-options.sh` pins the two lists together.

/// The second month the two-month (medium) widget shows.
enum Companion: String, AppEnum {
    case next, previous

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Second Month"
    static let caseDisplayRepresentations: [Companion: DisplayRepresentation] = [
        .next: "Next",
        .previous: "Previous",
    ]

    var coreOption: LeapCore.Companion {
        LeapCore.Companion(rawValue: rawValue) ?? .next
    }
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

    var coreOption: LeapCore.DisplayedMonth {
        LeapCore.DisplayedMonth(rawValue: rawValue) ?? .current
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

    var coreOption: LeapCore.FirstWeekday { LeapCore.FirstWeekday(rawValue: rawValue) ?? .system }
}

enum MonthNumberDisplay: String, AppEnum {
    case off, arabic, roman

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Month Number"
    static let caseDisplayRepresentations: [MonthNumberDisplay: DisplayRepresentation] = [
        .off: "Off",
        .arabic: "Number (6)",
        .roman: "Roman (VI)",
    ]

    var coreOption: LeapCore.MonthNumberDisplay {
        LeapCore.MonthNumberDisplay(rawValue: rawValue) ?? .off
    }
}

enum ClickAction: String, AppEnum {
    case appleCalendar, fantastical, googleCalendar, doNothing

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Click Opens"
    static let caseDisplayRepresentations: [ClickAction: DisplayRepresentation] = [
        .appleCalendar: DisplayRepresentation(title: "Default Calendar",
                                              subtitle: "ical://"),
        .fantastical: DisplayRepresentation(title: "Fantastical",
                                            subtitle: "x-fantastical3://"),
        .googleCalendar: DisplayRepresentation(title: "Google Calendar",
                                               subtitle: "calendar.google.com"),
        .doNothing: DisplayRepresentation(title: "Nothing"),
    ]

    var coreOption: LeapCore.ClickAction {
        LeapCore.ClickAction(rawValue: rawValue) ?? .appleCalendar
    }
}

struct CalendarConfigIntent: WidgetConfigurationIntent, CalendarConfiguration {
    static let title: LocalizedStringResource = "Calendar Options"

    @Parameter(title: "Second Month", default: .next)
    var companion: Companion

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

    var settings: CalendarSettings {
        CalendarSettings(monthOffsets: companion.coreOption.monthOffsets,
                         firstWeekday: firstWeekday.coreOption,
                         showWeekNumbers: showWeekNumbers,
                         showOutsideDays: showOutsideDays,
                         showYear: showYear,
                         monthNumber: monthNumber.coreOption,
                         clickAction: clickAction.coreOption)
    }

    static var parameterSummary: some ParameterSummary {
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

struct SmallCalendarConfigIntent: WidgetConfigurationIntent, CalendarConfiguration {
    static let title: LocalizedStringResource = "Calendar Options"

    @Parameter(title: "Month", default: .current)
    var month: DisplayedMonth

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

    var settings: CalendarSettings {
        CalendarSettings(monthOffsets: month.coreOption.monthOffsets,
                         firstWeekday: firstWeekday.coreOption,
                         showWeekNumbers: showWeekNumbers,
                         showOutsideDays: showOutsideDays,
                         showYear: showYear,
                         monthNumber: monthNumber.coreOption,
                         clickAction: clickAction.coreOption)
    }

    static var parameterSummary: some ParameterSummary {
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
