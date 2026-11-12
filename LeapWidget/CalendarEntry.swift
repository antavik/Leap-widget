import WidgetKit
import LeapCore

struct CalendarEntry: TimelineEntry {
    let model: CalendarEntryModel

    var date: Date { model.date }

    init(_ model: CalendarEntryModel) {
        self.model = model
    }

    init(date: Date,
         config: some CalendarConfiguration,
         calendar: Calendar = .autoupdatingCurrent) {
        let settings = config.settings
        self.init(CalendarEntryModel(
            date: date,
            settings: settings,
            builder: MonthModelBuilder(calendar: calendar,
                                       options: settings.monthOptions)))
    }
}
