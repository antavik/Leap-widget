import AppIntents
import QuaterlyCore

enum MonthSpan: String, AppEnum {
    case one, two, three

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Months"
    static let caseDisplayRepresentations: [MonthSpan: DisplayRepresentation] = [
        .one: "1 Month",
        .two: "2 Months",
        .three: "3 Months",
    ]

    var count: Int {
        switch self {
        case .one: 1
        case .two: 2
        case .three: 3
        }
    }
}

enum Companion: String, AppEnum {
    case previous, next

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Second Month"
    static let caseDisplayRepresentations: [Companion: DisplayRepresentation] = [
        .previous: "Previous",
        .next: "Next",
    ]
}

enum FirstWeekday: String, AppEnum {
    case system, monday, tuesday, wednesday, thursday, friday, saturday, sunday

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "First Day of Week"
    static let caseDisplayRepresentations: [FirstWeekday: DisplayRepresentation] = [
        .system: "System Default",
        .monday: "Monday",
        .tuesday: "Tuesday",
        .wednesday: "Wednesday",
        .thursday: "Thursday",
        .friday: "Friday",
        .saturday: "Saturday",
        .sunday: "Sunday",
    ]

    /// `Calendar` weekday convention: 1 = Sunday … 7 = Saturday; `nil` = system.
    var calendarWeekday: Int? {
        switch self {
        case .system: nil
        case .sunday: 1
        case .monday: 2
        case .tuesday: 3
        case .wednesday: 4
        case .thursday: 5
        case .friday: 6
        case .saturday: 7
        }
    }
}

struct CalendarConfigIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Calendar Options"

    @Parameter(title: "Months", default: .one)
    var span: MonthSpan

    @Parameter(title: "Second Month", default: .next)
    var companion: Companion

    @Parameter(title: "First Day of Week", default: .system)
    var firstWeekday: FirstWeekday

    @Parameter(title: "Week Numbers", default: false)
    var showWeekNumbers: Bool

    static var parameterSummary: some ParameterSummary {
        When(\CalendarConfigIntent.$span, .equalTo, .two) {
            Summary("Show \(\.$span)") {   // companion shown only for the 2-month span
                \.$companion
                \.$firstWeekday
                \.$showWeekNumbers
            }
        } otherwise: {
            Summary("Show \(\.$span)") {
                \.$firstWeekday
                \.$showWeekNumbers
            }
        }
    }
}

extension CalendarConfigIntent {
    var renderConfig: WidgetConfig {
        WidgetConfig(span: span.count,
                     companionPrevious: companion == .previous,
                     options: MonthOptions(firstWeekday: firstWeekday.calendarWeekday,
                                           showWeekNumbers: showWeekNumbers))
    }
}
