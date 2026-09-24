import WidgetKit
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

    /// A one-off entry – placeholder, snapshot, preview.
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
