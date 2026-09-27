import AppIntents
import LeapCore

// Case lists and display names only; every mapping lives in
// `LeapCore.CalendarSettings`. Each is the twin of a plain enum in
// `LeapCore.WidgetOptions`, bridged by raw value through `coreOption` – see that
// file for why. `scripts/check-widget-options.sh` pins the two lists together.

/// A fixed-choice widget parameter, as an `AppEntity` looked up by raw value.
///
/// Not `AppEnum`: from macOS 26.5 WidgetKit hands a saved `AppEnum` parameter
/// to the extension as nil (FB22848510), so every choice fell back to its
/// default – the month number never appeared. Entities resolve through
/// `WidgetOptionQuery`, which decodes the stored raw value itself.
protocol WidgetOption: AppEntity, CaseIterable, Hashable, RawRepresentable
where ID == String, RawValue == String {
    /// What a parameter holds before anyone picks, or when its value is lost.
    static var fallback: Self { get }
    static var caseDisplayRepresentations: [Self: DisplayRepresentation] { get }
}

extension WidgetOption {
    var id: String { rawValue }

    var displayRepresentation: DisplayRepresentation {
        Self.caseDisplayRepresentations[self] ?? DisplayRepresentation(stringLiteral: rawValue)
    }
}

/// One per option: the metadata processor rejects a generic query.
protocol WidgetOptionQuery: EntityQuery where Entity: WidgetOption {}

extension WidgetOptionQuery {
    func entities(for identifiers: [String]) async throws -> [Entity] {
        identifiers.compactMap(Entity.init(rawValue:))
    }

    func suggestedEntities() async throws -> [Entity] {
        Array(Entity.allCases)
    }

    func defaultResult() async -> Entity? {
        .fallback
    }
}

/// The second month the two-month (medium) widget shows.
enum Companion: String, WidgetOption {
    case next, previous

    static let fallback: Companion = .next
    static let defaultQuery = CompanionQuery()

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Second Month"
    static let caseDisplayRepresentations: [Companion: DisplayRepresentation] = [
        .next: "Next",
        .previous: "Previous",
    ]

    var coreOption: LeapCore.Companion {
        LeapCore.Companion(rawValue: rawValue) ?? .next
    }
}

struct CompanionQuery: WidgetOptionQuery {
    typealias Entity = Companion
}

/// Which month the single-month (small) widget renders, relative to today.
enum DisplayedMonth: String, WidgetOption {
    case current, next, previous

    static let fallback: DisplayedMonth = .current
    static let defaultQuery = DisplayedMonthQuery()

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

struct DisplayedMonthQuery: WidgetOptionQuery {
    typealias Entity = DisplayedMonth
}

enum FirstWeekday: String, WidgetOption {
    case system, monday, sunday

    static let fallback: FirstWeekday = .system
    static let defaultQuery = FirstWeekdayQuery()

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "First Day of Week"
    static let caseDisplayRepresentations: [FirstWeekday: DisplayRepresentation] = [
        .system: "System Default",
        .monday: "Monday",
        .sunday: "Sunday",
    ]

    var coreOption: LeapCore.FirstWeekday { LeapCore.FirstWeekday(rawValue: rawValue) ?? .system }
}

struct FirstWeekdayQuery: WidgetOptionQuery {
    typealias Entity = FirstWeekday
}

enum MonthNumberDisplay: String, WidgetOption {
    case off, arabic, roman

    static let fallback: MonthNumberDisplay = .off
    static let defaultQuery = MonthNumberDisplayQuery()

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

struct MonthNumberDisplayQuery: WidgetOptionQuery {
    typealias Entity = MonthNumberDisplay
}

enum ClickAction: String, WidgetOption {
    case appleCalendar, fantastical, googleCalendar, doNothing

    static let fallback: ClickAction = .appleCalendar
    static let defaultQuery = ClickActionQuery()

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

struct ClickActionQuery: WidgetOptionQuery {
    typealias Entity = ClickAction
}

struct CalendarConfigIntent: WidgetConfigurationIntent, CalendarConfiguration {
    static let title: LocalizedStringResource = "Calendar Options"

    @Parameter(title: "Second Month")
    var companion: Companion?

    @Parameter(title: "First Day of Week")
    var firstWeekday: FirstWeekday?

    @Parameter(title: "Week Numbers", default: false)
    var showWeekNumbers: Bool

    @Parameter(title: "Adjacent Month Days", default: true)
    var showOutsideDays: Bool

    @Parameter(title: "Show Year", default: true)
    var showYear: Bool

    @Parameter(title: "Month Number")
    var monthNumber: MonthNumberDisplay?

    @Parameter(title: "Click Opens")
    var clickAction: ClickAction?

    var settings: CalendarSettings {
        CalendarSettings(monthOffsets: (companion ?? .fallback).coreOption.monthOffsets,
                         firstWeekday: (firstWeekday ?? .fallback).coreOption,
                         showWeekNumbers: showWeekNumbers,
                         showOutsideDays: showOutsideDays,
                         showYear: showYear,
                         monthNumber: (monthNumber ?? .fallback).coreOption,
                         clickAction: (clickAction ?? .fallback).coreOption)
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

    @Parameter(title: "Month")
    var month: DisplayedMonth?

    @Parameter(title: "First Day of Week")
    var firstWeekday: FirstWeekday?

    @Parameter(title: "Week Numbers", default: false)
    var showWeekNumbers: Bool

    @Parameter(title: "Adjacent Month Days", default: true)
    var showOutsideDays: Bool

    @Parameter(title: "Show Year", default: true)
    var showYear: Bool

    @Parameter(title: "Month Number")
    var monthNumber: MonthNumberDisplay?

    @Parameter(title: "Click Opens")
    var clickAction: ClickAction?

    var settings: CalendarSettings {
        CalendarSettings(monthOffsets: (month ?? .fallback).coreOption.monthOffsets,
                         firstWeekday: (firstWeekday ?? .fallback).coreOption,
                         showWeekNumbers: showWeekNumbers,
                         showOutsideDays: showOutsideDays,
                         showYear: showYear,
                         monthNumber: (monthNumber ?? .fallback).coreOption,
                         clickAction: (clickAction ?? .fallback).coreOption)
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
