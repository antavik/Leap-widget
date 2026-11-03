import WidgetKit
import AppIntents
import LeapCore

/// Serves both widgets; the intent decides how many months come back.
struct Provider<Configuration>: AppIntentTimelineProvider
where Configuration: WidgetConfigurationIntent & CalendarConfiguration {
    func placeholder(in context: Context) -> CalendarEntry {
        CalendarEntry(date: .now, config: Configuration())
    }

    func snapshot(for configuration: Configuration,
                  in context: Context) async -> CalendarEntry {
        CalendarEntry(date: .now, config: configuration)
    }

    func timeline(for configuration: Configuration,
                  in context: Context) async -> Timeline<CalendarEntry> {
        // Now + the next two midnights: the today marker flips at 00:00.
        let entries = calendarEntries(for: configuration.settings,
                                      now: .now,
                                      calendar: .autoupdatingCurrent)

        return Timeline(entries: entries.map(CalendarEntry.init), policy: .atEnd)
    }
}
