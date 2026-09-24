import WidgetKit
import AppIntents
import LeapCore

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
