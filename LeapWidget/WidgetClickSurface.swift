import SwiftUI
import AppIntents
import LeapCore

struct WidgetClickSurface<Content: View>: View {
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
