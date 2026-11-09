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
        await timeline(for: configuration,
                       now: .now,
                       calendar: .autoupdatingCurrent)
    }

    /// Entries stay now plus the next two midnights, so today flips at 00:00.
    /// Reload at the first future midnight to reduce the risk of a desktop
    /// host keeping yesterday's archived entry until the timeline ends.
    func timeline(for configuration: Configuration,
                  now: Date,
                  calendar: Calendar) async -> Timeline<CalendarEntry> {
        let entries = calendarEntries(for: configuration.settings,
                                      now: now,
                                      calendar: calendar).map(CalendarEntry.init)

        // The second of the three entries is always strictly after `now`:
        // the next local midnight, even when `now` is already midnight.
        let policy = entries.dropFirst().first
            .map { TimelineReloadPolicy.after($0.date) } ?? .atEnd

        return Timeline(entries: entries, policy: policy)
    }
}
