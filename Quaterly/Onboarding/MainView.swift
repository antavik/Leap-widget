import SwiftUI
import WidgetKit
import QuaterlyCore

/// Onboarding guide (§4.7) + cross-instance settings (§4.8) in one window.
struct MainView: View {
    @State private var widgetAdded = false

    // Poll runs only while this view — and therefore the window — is alive (§4.11).
    private let placementPoll = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header
            OnboardingStep(number: 1,
                           symbol: "menubar.dock.rectangle",
                           title: "Add to the Desktop",
                           text: "Right-click the Desktop, choose “Edit Widgets…”, search for “Quaterly”, then drag the Calendar widget anywhere on the Desktop.")
            OnboardingStep(number: 2,
                           symbol: "bell.badge",
                           title: "Add to Notification Center",
                           text: "Click the clock in the menu bar, scroll to the bottom, choose “Edit Widgets”, and add the Calendar widget there.")
            OnboardingStep(number: 3,
                           symbol: "slider.horizontal.3",
                           title: "Configure",
                           text: "Right-click the placed widget and choose “Edit Calendar” to pick the month span, first day of the week, and week numbers.")
            placementStatus
            Divider()
            SettingsSection()
        }
        .padding(24)
        .frame(width: 480)
        .onAppear(perform: pollPlacement)
        .onReceive(placementPoll) { _ in pollPlacement() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Quaterly")
                .font(.title.bold())
            Text("A calendar widget for the Desktop and Notification Center. macOS places widgets itself — the three steps below take about a minute.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var placementStatus: some View {
        Label {
            Text(widgetAdded ? "Widget added ✓" : "Waiting for the first widget…")
        } icon: {
            Image(systemName: widgetAdded ? "checkmark.circle.fill" : "hourglass")
                .foregroundStyle(widgetAdded ? .green : .secondary)
        }
        .font(.callout.weight(.medium))
    }

    /// §4.7 step 3: flips the status once a Quaterly widget shows up anywhere.
    private func pollPlacement() {
        WidgetCenter.shared.getCurrentConfigurations { result in
            guard case .success(let widgets) = result else { return }
            let added = widgets.contains { $0.kind == WidgetKind.calendar }
            DispatchQueue.main.async {
                widgetAdded = added
            }
        }
    }
}

private struct OnboardingStep: View {
    let number: Int
    let symbol: String
    let title: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(number). \(title)")
                    .font(.headline)
                Text(text)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

#Preview {
    MainView()
}
