import AppIntents

/// In-process no-op for the "Nothing" click action: avoids launching the host
/// app, though WidgetKit still reloads the timeline.
struct DoNothingIntent: AppIntent {
    static let title: LocalizedStringResource = "Do Nothing"
    static let isDiscoverable = false

    func perform() async throws -> some IntentResult { .result() }
}
