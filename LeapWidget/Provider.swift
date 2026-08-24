import WidgetKit
import LeapCore

struct CalendarEntry: TimelineEntry {
    let date: Date
    let config: CalendarConfigIntent
    let models: [MonthModel]
    let yearLabel: String?

    init(date: Date, config: CalendarConfigIntent, family: WidgetLayoutFamily) {
        let render = config.renderConfig
        self.date = date
        self.config = config
        self.models = monthModels(containing: date, family: family, config: render)
        self.yearLabel = currentYearLabel(for: date, config: render)
    }
}

struct Provider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> CalendarEntry {
        CalendarEntry(date: Date.now, config: CalendarConfigIntent(),
                      family: layoutFamily(for: context))
    }

    func snapshot(for configuration: CalendarConfigIntent, in context: Context) async -> CalendarEntry {
        CalendarEntry(date: Date.now, config: configuration,
                      family: layoutFamily(for: context))
    }

    func timeline(for configuration: CalendarConfigIntent, in context: Context) async -> Timeline<CalendarEntry> {
        // Now + the next two midnights, `.atEnd`: the today marker flips
        // at 00:00 at ~1 reload/day.
        let dates = timelineDates(from: Date.now, calendar: Calendar.autoupdatingCurrent)
        let family = layoutFamily(for: context)
        let entries = dates.map { CalendarEntry(date: $0, config: configuration, family: family) }
        return Timeline(entries: entries, policy: .atEnd)
    }

    private func layoutFamily(for context: Context) -> WidgetLayoutFamily {
        switch context.family {
        case .systemMedium: .medium
        default: .small
        }
    }
}

struct SmallCalendarEntry: TimelineEntry {
    let date: Date
    let config: SmallCalendarConfigIntent
    let model: MonthModel
    let yearLabel: String?

    init(date: Date, config: SmallCalendarConfigIntent,
         calendar: Calendar = .autoupdatingCurrent) {
        let model = monthModel(containing: date,
                               offset: config.month.offset,
                               calendar: calendar,
                               today: date,
                               options: config.monthOptions)
        self.date = date
        self.config = config
        self.model = model
        self.yearLabel = config.showYear ? LeapCore.yearLabel(forYear: model.year) : nil
    }
}

struct SmallProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> SmallCalendarEntry {
        SmallCalendarEntry(date: Date.now, config: SmallCalendarConfigIntent())
    }

    func snapshot(for configuration: SmallCalendarConfigIntent,
                  in context: Context) async -> SmallCalendarEntry {
        SmallCalendarEntry(date: Date.now, config: configuration)
    }

    func timeline(for configuration: SmallCalendarConfigIntent,
                  in context: Context) async -> Timeline<SmallCalendarEntry> {
        let dates = timelineDates(from: Date.now, calendar: Calendar.autoupdatingCurrent)
        let entries = dates.map { SmallCalendarEntry(date: $0, config: configuration) }
        return Timeline(entries: entries, policy: .atEnd)
    }
}
