import SwiftUI

struct MainView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header
            OnboardingStep(number: 1,
                           symbol: "menubar.dock.rectangle",
                           title: "Add to the Desktop",
                           text: "Right-click the Desktop, choose “Edit Widgets…”, search for “Leap”, then drag the Two Months or Month widget anywhere on the Desktop.")
            OnboardingStep(number: 2,
                           symbol: "bell.badge",
                           title: "Add to Notification Center",
                           text: "Click the clock in the menu bar, scroll to the bottom, choose “Edit Widgets”, and add either widget there.")
            OnboardingStep(number: 3,
                           symbol: "slider.horizontal.3",
                           title: "Configure",
                           text: "Right-click the placed widget and choose its “Edit” item to pick which months to show, first day of the week, week numbers, and which app a click opens. Each widget keeps its own settings.")
        }
        .padding(24)
        .frame(width: 480)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Leap")
                .font(.title.bold())
            Text("A calendar widget for the Desktop and Notification Center. macOS places widgets itself – the three steps below take about a minute.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
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
