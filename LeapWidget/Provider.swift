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
        timeline(for: configuration, now: .now, calendar: .autoupdatingCurrent)
    }

    /// Entries are now plus the next two midnights: the day flips at 00:00 without a reload,
    /// but the refresh is still scheduled for the first midnight so a stale host redraws
    /// immediately and the later midnight covers a delayed system reload.
    func timeline(for configuration: Configuration,
                  now: Date,
                  calendar: Calendar) -> Timeline<CalendarEntry> {
        let entries = calendarEntries(for: configuration.settings,
                                      now: now,
                                      calendar: calendar).map(CalendarEntry.init)
        let nextMidnight = entries.first { $0.date > now }?.date

        return Timeline(entries: entries,
                        policy: nextMidnight.map { .after($0) } ?? .atEnd)
    }
}
