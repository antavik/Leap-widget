import SwiftUI
import WidgetKit
import QuaterlyCore

/// Cross-instance defaults (§4.8). Saved on submit, not per keystroke, so
/// widget reloads fire only on an actual change (§4.11).
struct SettingsSection: View {
    @State private var scheme = QuaterlySettings.launchCalendarScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Advanced")
                .font(.headline)
            HStack {
                Text("Calendar URL scheme")
                TextField(QuaterlySettings.defaultLaunchCalendarScheme, text: $scheme)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 180)
                    .onSubmit(save)
            }
            Text("Clicking a widget opens the app registered for this URL scheme. Leave as \(QuaterlySettings.defaultLaunchCalendarScheme) to use your default calendar app; set e.g. x-fantastical3:// to force a specific one.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func save() {
        guard scheme != QuaterlySettings.launchCalendarScheme else { return }
        QuaterlySettings.launchCalendarScheme = scheme
        scheme = QuaterlySettings.launchCalendarScheme   // reflect normalization
        WidgetCenter.shared.reloadAllTimelines()          // §4.6
    }
}
