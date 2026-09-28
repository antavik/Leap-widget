import AppIntents
import LeapCore

// Display names and pickers for the `LeapCore.WidgetOptions` enums; every
// mapping lives in `LeapCore.CalendarSettings`.

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
extension Companion: WidgetOption {
    static let fallback: Companion = .next

    var title: LocalizedStringResource {
        switch self {
        case .next: "Next"
        case .previous: "Previous"
        }
    }
}

struct CompanionOptions: WidgetOptionProvider {
    typealias Option = Companion
}

/// Which month the single-month (small) widget renders, relative to today.
extension DisplayedMonth: WidgetOption {
    static let fallback: DisplayedMonth = .current

    var title: LocalizedStringResource {
        switch self {
        case .current: "Current"
        case .next: "Next"
        case .previous: "Previous"
        }
    }
}

struct DisplayedMonthOptions: WidgetOptionProvider {
    typealias Option = DisplayedMonth
}

extension FirstWeekday: WidgetOption {
    static let fallback: FirstWeekday = .system

    var title: LocalizedStringResource {
        switch self {
        case .system: "System Default"
        case .monday: "Monday"
        case .sunday: "Sunday"
        }
    }
}

struct FirstWeekdayOptions: WidgetOptionProvider {
    typealias Option = FirstWeekday
}

extension MonthNumberDisplay: WidgetOption {
    static let fallback: MonthNumberDisplay = .off

    var title: LocalizedStringResource {
        switch self {
        case .off: "Off"
        case .arabic: "Number (6)"
        case .roman: "Roman (VI)"
        }
    }
}

struct MonthNumberDisplayOptions: WidgetOptionProvider {
    typealias Option = MonthNumberDisplay
}

extension ClickAction: WidgetOption {
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
        CalendarSettings(monthOffsets: Companion(saved: companion).monthOffsets,
                         firstWeekday: FirstWeekday(saved: firstWeekday),
                         showWeekNumbers: showWeekNumbers,
                         showOutsideDays: showOutsideDays,
                         showYear: showYear,
                         monthNumber: MonthNumberDisplay(saved: monthNumber),
                         clickAction: ClickAction(saved: clickAction))
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
        CalendarSettings(monthOffsets: DisplayedMonth(saved: month).monthOffsets,
                         firstWeekday: FirstWeekday(saved: firstWeekday),
                         showWeekNumbers: showWeekNumbers,
                         showOutsideDays: showOutsideDays,
                         showYear: showYear,
                         monthNumber: MonthNumberDisplay(saved: monthNumber),
                         clickAction: ClickAction(saved: clickAction))
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
