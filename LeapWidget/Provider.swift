import WidgetKit
import AppIntents
import LeapCore

/// One entry shape for both widgets: the small one simply carries a
/// single-element `models`.
struct CalendarEntry: TimelineEntry {
    let date: Date
    let clickTarget: ClickPreset?
    let models: [MonthModel]
    let yearLabel: String?

    /// `builder` lets a timeline's entries share one calendar/locale/symbol
    /// setup; passing `nil` resolves a fresh one.
    init<Configuration: CalendarConfiguration>(date: Date,
                                               config: Configuration,
                                               builder: MonthModelBuilder? = nil) {
        let row = monthRow(containing: date,
                           offsets: config.monthOffsets,
                           showYear: config.showYear,
                           builder: builder ?? MonthModelBuilder(
                               calendar: .autoupdatingCurrent,
                               options: config.monthOptions))
        self.date = date
        self.clickTarget = config.clickAction.preset
        self.models = row.models
        self.yearLabel = row.yearLabel
    }
}

/// Serves both widgets; the intent decides how many months come back.
struct Provider<Configuration>: AppIntentTimelineProvider
where Configuration: WidgetConfigurationIntent & CalendarConfiguration {
    func placeholder(in context: Context) -> CalendarEntry {
        CalendarEntry(date: Date.now, config: Configuration())
    }

    func snapshot(for configuration: Configuration,
                  in context: Context) async -> CalendarEntry {
        CalendarEntry(date: Date.now, config: configuration)
    }

    func timeline(for configuration: Configuration,
                  in context: Context) async -> Timeline<CalendarEntry> {
        // Now + the next two midnights, `.atEnd`: the today marker flips
        // at 00:00 at ~1 reload/day.
        let calendar = Calendar.autoupdatingCurrent
        let dates = timelineDates(from: Date.now, calendar: calendar)

        // Every entry shares the reload's calendar and configuration, so one
        // builder covers them all; the setup dominates a month build.
        let builder = MonthModelBuilder(calendar: calendar,
                                        options: configuration.monthOptions)
        let entries = dates.map {
            CalendarEntry(date: $0, config: configuration, builder: builder)
        }
        return Timeline(entries: entries, policy: .atEnd)
    }
}
