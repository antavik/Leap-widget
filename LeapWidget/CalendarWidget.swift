import WidgetKit
import SwiftUI
import LeapCore

struct CalendarWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: Constants.Widgets.calendar,
                               intent: CalendarConfigIntent.self,
                               provider: Provider<CalendarConfigIntent>()) { entry in
            CalendarWidgetView(entry: entry)
                .containerBackground(.background, for: .widget)
        }
        .contentMarginsDisabled()
        .configurationDisplayName("Two Months")
        .galleryDescription("Two months at a glance – the current plus the previous or next.")
        .supportedFamilies([.systemMedium])
    }
}
