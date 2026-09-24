import WidgetKit
import SwiftUI
import LeapCore

struct SmallCalendarWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: Constants.Widgets.calendarSmall,
                               intent: SmallCalendarConfigIntent.self,
                               provider: Provider<SmallCalendarConfigIntent>()) { entry in
            CalendarWidgetView(entry: entry)
                .containerBackground(.background, for: .widget)
        }
        .contentMarginsDisabled()
        .configurationDisplayName("Month")
        .galleryDescription("One month at a glance – the current, previous, or next.")
        .supportedFamilies([.systemSmall])
    }
}

private func smallIntent(showing month: DisplayedMonth) -> SmallCalendarConfigIntent {
    let intent = SmallCalendarConfigIntent()
    intent.month = month
    return intent
}

#Preview("Current month", as: .systemSmall) {
    SmallCalendarWidget()
} timeline: {
    CalendarEntry(date: .now, config: smallIntent(showing: .current))
}

#Preview("Previous month – year boundary", as: .systemSmall) {
    SmallCalendarWidget()
} timeline: {
    CalendarEntry(date: Calendar.autoupdatingCurrent.date(
                      from: DateComponents(year: 2027, month: 1, day: 10))!,
                  config: smallIntent(showing: .previous))
}
