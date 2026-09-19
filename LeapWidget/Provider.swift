import WidgetKit
import AppIntents
import LeapCore

/// One entry shape for both widgets; the small one carries a single-element
/// `models`. Everything but WidgetKit conformance lives in
/// `LeapCore.CalendarEntryModel`, where it can be tested.
struct CalendarEntry: TimelineEntry {
    let model: CalendarEntryModel

    var date: Date { model.date }
    var clickTarget: ClickPreset? { model.clickTarget }
    var models: [MonthModel] { model.models }
    var yearLabel: String? { model.yearLabel }

    init(_ model: CalendarEntryModel) {
        self.model = model
    }

    /// A one-off entry — placeholder, snapshot, preview.
    init<Configuration: CalendarConfiguration>(date: Date,
                                               config: Configuration,
                                               calendar: Calendar = .autoupdatingCurrent) {
        let settings = config.settings
        self.init(CalendarEntryModel(
            date: date,
            settings: settings,
            builder: MonthModelBuilder(calendar: calendar,
                                       options: settings.monthOptions)))
    }
}

/// Serves both widgets; the intent decides how many months come back.
struct Provider<Configuration>: AppIntentTimelineProvider
where Configuration: WidgetConfigurationIntent & CalendarConfiguration {
    var now: @Sendable () -> Date = { .now }
    var calendar: @Sendable () -> Calendar = { .autoupdatingCurrent }

    func placeholder(in context: Context) -> CalendarEntry {
        CalendarEntry(date: now(), config: Configuration(), calendar: calendar())
    }

    func snapshot(for configuration: Configuration,
                  in context: Context) async -> CalendarEntry {
        CalendarEntry(date: now(), config: configuration, calendar: calendar())
    }

    func timeline(for configuration: Configuration,
                  in context: Context) async -> Timeline<CalendarEntry> {
        // Now + the next two midnights: the today marker flips at 00:00.
        let entries = calendarEntries(for: configuration.settings,
                                      now: now(),
                                      calendar: calendar())

        return Timeline(entries: entries.map(CalendarEntry.init), policy: .atEnd)
    }
}
