import AppIntents
import LeapCore

// Case lists and display names only; every mapping lives in
// `LeapCore.CalendarSettings`. Each is the twin of a plain enum in
// `LeapCore.WidgetOptions`, bridged by raw value through `coreOption` – see that
// file for why. `scripts/check-widget-options.sh` pins the two lists together.

/// A fixed-choice widget parameter, saved as its raw value in a `String`.
///
/// Not `AppEnum` or `AppEntity`: on macOS 26+ the extension resolves those
/// through `linkd`, which refuses a bundle without a Team ID
/// ("requiresValidatedBundle"). Leap is ad-hoc signed, so every saved choice
/// arrived as nil and fell back – the month number never appeared. A `String`,
/// like the `Bool` parameters, needs no lookup.
protocol WidgetOption: CaseIterable, RawRepresentable<String> {
    /// What a parameter holds before anyone picks, or when its value is lost.
    static var fallback: Self { get }
    var title: LocalizedStringResource { get }
    var subtitle: LocalizedStringResource? { get }
}

extension WidgetOption {
    var subtitle: LocalizedStringResource? { nil }

    /// The saved choice, or the fallback when it is missing or unknown.
    init(saved rawValue: String?) {
        self = rawValue.flatMap(Self.init(rawValue:)) ?? .fallback
    }
}

/// The picker for a `WidgetOption` parameter: every case, titled. One per
/// option – the metadata processor finds no record of a generic provider.
protocol WidgetOptionProvider: DynamicOptionsProvider {
    associatedtype Option: WidgetOption
}

extension WidgetOptionProvider {
    func results() async throws -> IntentItemCollection<String> {
        IntentItemCollection(sections: [
            IntentItemSection(items: Option.allCases.map {
                IntentItem($0.rawValue, title: $0.title, subtitle: $0.subtitle)
            }),
        ])
    }

    func defaultResult() async -> String? {
        Option.fallback.rawValue
    }
}

/// The second month the two-month (medium) widget shows.
enum Companion: String, WidgetOption {
    case next, previous

    static let fallback: Companion = .next

    var title: LocalizedStringResource {
        switch self {
        case .next: "Next"
        case .previous: "Previous"
        }
    }

    var coreOption: LeapCore.Companion {
        LeapCore.Companion(rawValue: rawValue) ?? .next
    }
}

struct CompanionOptions: WidgetOptionProvider {
    typealias Option = Companion
}

/// Which month the single-month (small) widget renders, relative to today.
enum DisplayedMonth: String, WidgetOption {
    case current, next, previous

    static let fallback: DisplayedMonth = .current

    var title: LocalizedStringResource {
        switch self {
        case .current: "Current"
        case .next: "Next"
        case .previous: "Previous"
        }
    }

    var coreOption: LeapCore.DisplayedMonth {
        LeapCore.DisplayedMonth(rawValue: rawValue) ?? .current
    }
}

struct DisplayedMonthOptions: WidgetOptionProvider {
    typealias Option = DisplayedMonth
}

enum FirstWeekday: String, WidgetOption {
    case system, monday, sunday

    static let fallback: FirstWeekday = .system

    var title: LocalizedStringResource {
        switch self {
        case .system: "System Default"
        case .monday: "Monday"
        case .sunday: "Sunday"
        }
    }

    var coreOption: LeapCore.FirstWeekday { LeapCore.FirstWeekday(rawValue: rawValue) ?? .system }
}

struct FirstWeekdayOptions: WidgetOptionProvider {
    typealias Option = FirstWeekday
}

enum MonthNumberDisplay: String, WidgetOption {
    case off, arabic, roman

    static let fallback: MonthNumberDisplay = .off

    var title: LocalizedStringResource {
        switch self {
        case .off: "Off"
        case .arabic: "Number (6)"
        case .roman: "Roman (VI)"
        }
    }

    var coreOption: LeapCore.MonthNumberDisplay {
        LeapCore.MonthNumberDisplay(rawValue: rawValue) ?? .off
    }
}

struct MonthNumberDisplayOptions: WidgetOptionProvider {
    typealias Option = MonthNumberDisplay
}

enum ClickAction: String, WidgetOption {
    case appleCalendar, fantastical, googleCalendar, doNothing

    static let fallback: ClickAction = .appleCalendar

    var title: LocalizedStringResource {
        switch self {
        case .appleCalendar: "Default Calendar"
        case .fantastical: "Fantastical"
        case .googleCalendar: "Google Calendar"
        case .doNothing: "Nothing"
        }
    }

    var subtitle: LocalizedStringResource? {
        switch self {
        case .appleCalendar: "ical://"
        case .fantastical: "x-fantastical3://"
        case .googleCalendar: "calendar.google.com"
        case .doNothing: nil
        }
    }

    var coreOption: LeapCore.ClickAction {
        LeapCore.ClickAction(rawValue: rawValue) ?? .appleCalendar
    }
}

struct ClickActionOptions: WidgetOptionProvider {
    typealias Option = ClickAction
}

struct CalendarConfigIntent: WidgetConfigurationIntent, CalendarConfiguration {
    static let title: LocalizedStringResource = "Calendar Options"

    @Parameter(title: "Second Month", optionsProvider: CompanionOptions())
    var companion: String?

    @Parameter(title: "First Day of Week", optionsProvider: FirstWeekdayOptions())
    var firstWeekday: String?

    @Parameter(title: "Week Numbers", default: false)
    var showWeekNumbers: Bool

    @Parameter(title: "Adjacent Month Days", default: true)
    var showOutsideDays: Bool

    @Parameter(title: "Show Year", default: true)
    var showYear: Bool

    @Parameter(title: "Month Number", optionsProvider: MonthNumberDisplayOptions())
    var monthNumber: String?

    @Parameter(title: "Click Opens", optionsProvider: ClickActionOptions())
    var clickAction: String?

    var settings: CalendarSettings {
        CalendarSettings(monthOffsets: Companion(saved: companion).coreOption.monthOffsets,
                         firstWeekday: FirstWeekday(saved: firstWeekday).coreOption,
                         showWeekNumbers: showWeekNumbers,
                         showOutsideDays: showOutsideDays,
                         showYear: showYear,
                         monthNumber: MonthNumberDisplay(saved: monthNumber).coreOption,
                         clickAction: ClickAction(saved: clickAction).coreOption)
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

    @Parameter(title: "Month", optionsProvider: DisplayedMonthOptions())
    var month: String?

    @Parameter(title: "First Day of Week", optionsProvider: FirstWeekdayOptions())
    var firstWeekday: String?

    @Parameter(title: "Week Numbers", default: false)
    var showWeekNumbers: Bool

    @Parameter(title: "Adjacent Month Days", default: true)
    var showOutsideDays: Bool

    @Parameter(title: "Show Year", default: true)
    var showYear: Bool

    @Parameter(title: "Month Number", optionsProvider: MonthNumberDisplayOptions())
    var monthNumber: String?

    @Parameter(title: "Click Opens", optionsProvider: ClickActionOptions())
    var clickAction: String?

    var settings: CalendarSettings {
        CalendarSettings(monthOffsets: DisplayedMonth(saved: month).coreOption.monthOffsets,
                         firstWeekday: FirstWeekday(saved: firstWeekday).coreOption,
                         showWeekNumbers: showWeekNumbers,
                         showOutsideDays: showOutsideDays,
                         showYear: showYear,
                         monthNumber: MonthNumberDisplay(saved: monthNumber).coreOption,
                         clickAction: ClickAction(saved: clickAction).coreOption)
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
