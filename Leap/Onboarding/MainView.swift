import SwiftUI
import LeapCore

struct MainView: View {
    private let steps: [OnboardingStep] = [
        OnboardingStep(symbol: "menubar.dock.rectangle",
                       title: "Add to the Desktop",
                       text: "Right-click the Desktop, choose “Edit Widgets…”, search for “Leap”, then drag the Two Months or Month widget anywhere on the Desktop."),
        OnboardingStep(symbol: "bell.badge",
                       title: "Add to Notification Center",
                       text: "Click the clock in the menu bar, scroll to the bottom, choose “Edit Widgets”, and add either widget there."),
        OnboardingStep(symbol: "slider.horizontal.3",
                       title: "Configure",
                       text: "Right-click the placed widget and choose its “Edit” item to pick which months to show, first day of the week, week numbers, and which app a click opens. Each widget keeps its own settings.")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header
            ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                OnboardingStepView(step: step, number: index + 1, total: steps.count)
            }
            donation
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

    private var donation: some View {
        VStack(spacing: 6) {
            Divider()
                .padding(.bottom, 8)
            Text("Enjoy Leap?")
                .foregroundStyle(.secondary)
            HStack(spacing: 14) {
                Link("You can buy me a coffee", destination: Constants.Links.donation)
                Link("Share your thoughts", destination: Constants.Mail.feedback)
            }
            .buttonStyle(.link)
            Text("Thank you!")
                .foregroundStyle(.secondary)
        }
        .font(.caption)
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity)
    }
}

private struct OnboardingStep: Identifiable {
    let symbol: String
    let title: LocalizedStringResource
    let text: LocalizedStringResource

    var id: String { symbol }
}

private struct OnboardingStepView: View {
    let step: OnboardingStep
    let number: Int
    let total: Int

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: step.symbol)
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(width: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(headline)
                    .font(.headline)
                Text(step.text)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spokenStep)
    }

    /// Already localized, so it goes through the non-localizing `Text` and
    /// `accessibilityLabel` initialisers.
    private var headline: String {
        "\(number). \(String(localized: step.title))"
    }

    private var spokenStep: String {
        String(localized: "Step \(number) of \(total). \(String(localized: step.title)). \(String(localized: step.text))",
               comment: "VoiceOver label for one onboarding step")
    }
}

#Preview {
    MainView()
}
