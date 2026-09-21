import WidgetKit
import SwiftUI
import AppIntents
import LeapCore

/// In-process no-op for the "Nothing" click action: avoids launching the host
/// app, though WidgetKit still reloads the timeline.
struct DoNothingIntent: AppIntent {
    static let title: LocalizedStringResource = "Do Nothing"
    static let isDiscoverable = false

    func perform() async throws -> some IntentResult { .result() }
}

/// No press feedback – the surface should feel inert, not interactive.
private struct InertButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
    }
}

private struct WidgetClickSurface<Content: View>: View {
    let target: ClickPreset?
    @ViewBuilder let content: Content

    var body: some View {
        if let relayURL = CalendarRelay.url(for: target) {
            content.widgetURL(relayURL)
        } else {
            Button(intent: DoNothingIntent()) { content }
                .buttonStyle(InertButtonStyle())
                .accessibilityRemoveTraits(.isButton)
                .accessibilityRespondsToUserInteraction(false)
        }
    }
}

#if DEBUG
enum BuildStamp {
    static let current: String = {
        let info = Bundle.main.infoDictionary
        let marketing = info?["CFBundleShortVersionString"] as? String ?? "?"

        guard let commit = info?["LeapBuildCommit"] as? String, !commit.isEmpty else {
            return "Version: \(marketing)."
        }

        return "Version: \(marketing) (\(commit))."
    }()
}
#endif

private extension WidgetConfiguration {
    func galleryDescription(_ text: LocalizedStringResource) -> some WidgetConfiguration {
#if DEBUG
        description("\(String(localized: text))\n\(BuildStamp.current)")
#else
        description(text)
#endif
    }
}

struct CalendarWidgetView: View {
    let entry: CalendarEntry

    var body: some View {
        WidgetClickSurface(target: entry.clickTarget) {
            CalendarSurface(models: entry.models, yearLabel: entry.yearLabel)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }
}

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
