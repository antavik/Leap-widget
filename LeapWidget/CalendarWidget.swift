import WidgetKit
import SwiftUI
import AppIntents
import LeapCore

/// Click target relayed to the host app, which resolves it to the calendar
/// app, or `nil` when a click should do nothing. Presets use opaque `action`
/// tokens resolved via `ClickPreset`, so `leap://` cannot open arbitrary URLs
/// from outside.
func calendarRelayURL(for target: ClickTarget) -> URL? {
    var components = URLComponents()
    components.scheme = "leap"
    components.host = "open-calendar"
    switch target {
    case .preset(let preset):
        components.queryItems = [URLQueryItem(name: "action", value: preset.rawValue)]
    case .customURL(let string):
        components.queryItems = [URLQueryItem(name: "url", value: string)]
    case .none:
        return nil
    }
    return components.url
}

/// In-process no-op for the "Nothing" click action, so the host app is never launched.
struct DoNothingIntent: AppIntent {
    static let title: LocalizedStringResource = "Do Nothing"
    static let isDiscoverable = false

    func perform() async throws -> some IntentResult { .result() }
}

/// No press feedback — the surface should feel inert, not interactive.
private struct InertButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
    }
}

/// Uses a relay URL when the widget should open something, otherwise an
/// in-process no-op button. A bare `widgetURL` would launch the host app for
/// nothing, and rapid clicks can race that launch-and-quit into showing its
/// window.
private struct WidgetClickSurface<Content: View>: View {
    let target: ClickTarget
    @ViewBuilder let content: Content

    var body: some View {
        if let relayURL = calendarRelayURL(for: target) {
            content.widgetURL(relayURL)
        } else {
            Button(intent: DoNothingIntent()) { content }
                .buttonStyle(InertButtonStyle())
                .accessibilityRemoveTraits(.isButton)
        }
    }
}

struct CalendarWidgetView: View {
    let entry: CalendarEntry

    var body: some View {
        WidgetClickSurface(target: entry.config.clickTarget) {
            MultiMonthView(models: entry.models,
                           yearLabel: entry.yearLabel)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }
}

struct SmallCalendarWidgetView: View {
    let entry: SmallCalendarEntry

    var body: some View {
        WidgetClickSurface(target: entry.config.clickTarget) {
            MultiMonthView(models: [entry.model], yearLabel: entry.yearLabel)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }
}

struct CalendarWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: WidgetKind.calendar,
                               intent: CalendarConfigIntent.self,
                               provider: Provider()) { entry in
            CalendarWidgetView(entry: entry)
                .padding(12)
                .containerBackground(.background, for: .widget)
        }
        .contentMarginsDisabled()
        .configurationDisplayName("Two Months")
        .description("Two months at a glance – the current plus the previous or next.")
        .supportedFamilies([.systemMedium])
    }
}

struct SmallCalendarWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: WidgetKind.calendarSmall,
                               intent: SmallCalendarConfigIntent.self,
                               provider: SmallProvider()) { entry in
            SmallCalendarWidgetView(entry: entry)
                .padding(12)
                .containerBackground(.background, for: .widget)
        }
        .contentMarginsDisabled()
        .configurationDisplayName("Month")
        .description("One month at a glance – the current, previous, or next.")
        .supportedFamilies([.systemSmall])
    }
}

// MARK: - Previews

private func smallIntent(showing month: DisplayedMonth) -> SmallCalendarConfigIntent {
    let intent = SmallCalendarConfigIntent()
    intent.month = month
    return intent
}

#Preview("Current month", as: .systemSmall) {
    SmallCalendarWidget()
} timeline: {
    SmallCalendarEntry(date: .now, config: smallIntent(showing: .current))
}

#Preview("Previous month – year boundary", as: .systemSmall) {
    SmallCalendarWidget()
} timeline: {
    SmallCalendarEntry(date: Calendar.autoupdatingCurrent.date(
                           from: DateComponents(year: 2027, month: 1, day: 10))!,
                       config: smallIntent(showing: .previous))
}
