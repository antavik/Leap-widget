import WidgetKit
import SwiftUI
import QuaterlyCore

struct CalendarWidgetView: View {
    @Environment(\.widgetFamily) private var family

    let entry: CalendarEntry

    var body: some View {
        MultiMonthView(date: entry.date,
                       family: layoutFamily,
                       config: entry.config.renderConfig)
    }

    private var layoutFamily: WidgetLayoutFamily {
        switch family {
        case .systemMedium: .medium
        case .systemLarge: .large
        case .systemExtraLarge: .extraLarge
        default: .small
        }
    }
}

struct CalendarWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: WidgetKind.calendar,
                               intent: CalendarConfigIntent.self,
                               provider: Provider()) { entry in
            CalendarWidgetView(entry: entry)
                .containerBackground(.background, for: .widget)
                .widgetURL(URL(string: "quaterly://open-calendar")!)
        }
        .configurationDisplayName("Calendar")
        .description("Month view — one, two, or three months at a glance.")
        .supportedFamilies(Self.families)
    }

    private static var families: [WidgetFamily] {
        if #available(macOS 15.0, *) {
            [.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge]
        } else {
            [.systemSmall, .systemMedium, .systemLarge]
        }
    }
}
