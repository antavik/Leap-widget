import WidgetKit
import SwiftUI
import AppIntents
import LeapCore

/// Relay URL for a click, or `nil` when a click should do nothing. The relay
/// names calendars only by opaque `ClickPreset` token, never by URL, so
/// `leap://` cannot be talked into opening something arbitrary from outside.
func calendarRelayURL(for preset: ClickPreset?) -> URL? {
    guard let preset else { return nil }

    var components = URLComponents()
    components.scheme = "leap"
    components.host = "open-calendar"
    components.queryItems = [URLQueryItem(name: "action", value: preset.rawValue)]

    return components.url
}

/// In-process no-op for the "Nothing" click action.
/// Avoids launching the host app, though WidgetKit still reloads the timeline.
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

private struct WidgetClickSurface<Content: View>: View {
    let target: ClickPreset?
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

enum BuildStamp {
    static let current: String = {
        let info = Bundle.main.infoDictionary
        let marketing = info?["CFBundleShortVersionString"] as? String ?? "?"

        guard let commit = info?["LeapBuildCommit"] as? String, !commit.isEmpty else {
            return "v\(marketing)"
        }

        return "v\(marketing) (\(commit))"
    }()

    static func stamped(_ text: String) -> LocalizedStringResource {
        LocalizedStringResource(stringLiteral: "\(text)\n\(current)")
    }
}

struct CalendarWidgetView: View {
    let entry: CalendarEntry

    var body: some View {
        WidgetClickSurface(target: entry.clickTarget) {
            MultiMonthView(models: entry.models, yearLabel: entry.yearLabel)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }
}

struct CalendarWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: WidgetKind.calendar,
                               intent: CalendarConfigIntent.self,
                               provider: Provider<CalendarConfigIntent>()) { entry in
            CalendarWidgetView(entry: entry)
                .padding(12)
                .containerBackground(.background, for: .widget)
        }
        .contentMarginsDisabled()
        .configurationDisplayName("Two Months")
        .description(BuildStamp.stamped("Two months at a glance – the current plus the previous or next."))
        .supportedFamilies([.systemMedium])
    }
}

struct SmallCalendarWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: WidgetKind.calendarSmall,
                               intent: SmallCalendarConfigIntent.self,
                               provider: Provider<SmallCalendarConfigIntent>()) { entry in
            CalendarWidgetView(entry: entry)
                .padding(12)
                .containerBackground(.background, for: .widget)
        }
        .contentMarginsDisabled()
        .configurationDisplayName("Month")
        .description(BuildStamp.stamped("One month at a glance – the current, previous, or next."))
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
    CalendarEntry(date: .now, config: smallIntent(showing: .current))
}

#Preview("Previous month – year boundary", as: .systemSmall) {
    SmallCalendarWidget()
} timeline: {
    CalendarEntry(date: Calendar.autoupdatingCurrent.date(
                      from: DateComponents(year: 2027, month: 1, day: 10))!,
                  config: smallIntent(showing: .previous))
}
