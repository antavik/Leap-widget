import WidgetKit
import QuaterlyCore

struct CalendarEntry: TimelineEntry {
    let date: Date
    let config: CalendarConfigIntent
}

struct Provider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> CalendarEntry {
        CalendarEntry(date: Date(), config: CalendarConfigIntent())
    }

    func snapshot(for configuration: CalendarConfigIntent, in context: Context) async -> CalendarEntry {
        CalendarEntry(date: Date(), config: configuration)
    }

    func timeline(for configuration: CalendarConfigIntent, in context: Context) async -> Timeline<CalendarEntry> {
        // Now + the next two midnights, `.atEnd` (§4.6): the today marker flips
        // at 00:00 at ~1 reload/day.
        let dates = timelineDates(from: Date(), calendar: Calendar.autoupdatingCurrent)
        let entries = dates.map { CalendarEntry(date: $0, config: configuration) }
        return Timeline(entries: entries, policy: .atEnd)
    }
}
