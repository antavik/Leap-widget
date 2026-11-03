import SwiftUI
import AppIntents
import LeapCore

struct WidgetClickSurface<Content: View>: View {
    let action: ClickAction
    @ViewBuilder let content: Content

    var body: some View {
        if let relayURL = CalendarRelay.url(for: action) {
            content.widgetURL(relayURL)
        } else {
            Button(intent: DoNothingIntent()) { content }
                .buttonStyle(InertButtonStyle())
                .accessibilityRemoveTraits(.isButton)
                .accessibilityRespondsToUserInteraction(false)
        }
    }
}
