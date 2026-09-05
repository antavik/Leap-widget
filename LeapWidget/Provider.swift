import WidgetKit
import LeapCore

struct CalendarEntry: TimelineEntry {
    let date: Date
    let config: CalendarConfigIntent
    let models: [MonthModel]
    let yearLabel: String?

    init(date: Date, config: CalendarConfigIntent, family: WidgetLayoutFamily,
         builder: MonthModelBuilder? = nil) {
        let render = config.renderConfig
        self.date = date
        self.config = config
        self.models = monthModels(containing: date, family: family, config: render,
                                  builder: builder ?? MonthModelBuilder(
                                      calendar: .autoupdatingCurrent,
                                      options: render.options))
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
        let calendar = Calendar.autoupdatingCurrent
        let dates = timelineDates(from: Date.now, calendar: calendar)
        let family = layoutFamily(for: context)

        // Every entry shares the reload's calendar and configuration, so one
        // builder covers them all; the setup dominates a month build.
        let builder = MonthModelBuilder(calendar: calendar,
                                        options: configuration.renderConfig.options)
        let entries = dates.map {
            CalendarEntry(date: $0, config: configuration, family: family, builder: builder)
        }
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

    /// `builder` lets a timeline's entries share one calendar/locale/symbol
    /// setup; passing `nil` resolves a fresh one from `calendar`.
    init(date: Date, config: SmallCalendarConfigIntent,
         calendar: Calendar = .autoupdatingCurrent,
         builder: MonthModelBuilder? = nil) {
        let builder = builder ?? MonthModelBuilder(calendar: calendar,
                                                   options: config.monthOptions)
        let model = builder.model(containing: date,
                                  offset: config.month.offset,
                                  today: date)
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
        let calendar = Calendar.autoupdatingCurrent
        let dates = timelineDates(from: Date.now, calendar: calendar)
        let builder = MonthModelBuilder(calendar: calendar, options: configuration.monthOptions)
        let entries = dates.map {
            SmallCalendarEntry(date: $0, config: configuration, builder: builder)
        }
        return Timeline(entries: entries, policy: .atEnd)
    }
}
