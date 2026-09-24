import SwiftUI

public struct OnboardingView: View {
    private static let steps: [OnboardingStep] = [
        OnboardingStep(
            symbol: "menubar.dock.rectangle",
            title: LocalizedStringResource("Add to the Desktop",
                                           bundle: .atURL(Bundle.module.bundleURL)),
            text: LocalizedStringResource("Right-click the Desktop, choose “Edit Widgets…”, search for “Leap”, then drag the Two Months or Month widget anywhere on the Desktop.",
                                          bundle: .atURL(Bundle.module.bundleURL))),
        OnboardingStep(
            symbol: "bell.badge",
            title: LocalizedStringResource("Add to Notification Center",
                                           bundle: .atURL(Bundle.module.bundleURL)),
            text: LocalizedStringResource("Click the clock in the menu bar, scroll to the bottom, choose “Edit Widgets”, and add either widget there.",
                                          bundle: .atURL(Bundle.module.bundleURL))),
        OnboardingStep(
            symbol: "slider.horizontal.3",
            title: LocalizedStringResource("Configure",
                                           bundle: .atURL(Bundle.module.bundleURL)),
            text: LocalizedStringResource("Right-click the placed widget and choose its “Edit” item to pick which months to show, first day of the week, week numbers, and which app a click opens. Each widget keeps its own settings.",
                                          bundle: .atURL(Bundle.module.bundleURL)))
    ]

    public static let width: CGFloat = 480

    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    private let donationURL: URL
    private let feedbackURL: URL

    public init(donationURL: URL = Constants.Links.donation,
                feedbackURL: URL = Constants.Mail.feedback) {
        self.donationURL = donationURL
        self.feedbackURL = feedbackURL
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header
            ForEach(Array(Self.steps.enumerated()), id: \.element.id) { index, step in
                OnboardingStepView(step: step,
                                   number: index + 1,
                                   total: Self.steps.count)
            }
            donation
        }
        .padding(24)
        .frame(width: Self.width)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Leap", bundle: .module)
                .font(.title.bold())
            Text("A calendar widget for the Desktop and Notification Center. macOS places widgets itself – the three steps below take about a minute.",
                 bundle: .module)
                .font(.callout)
                .foregroundStyle(Theme.secondaryText(contrast: colorSchemeContrast))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var donation: some View {
        VStack(spacing: 6) {
            Divider()
                .padding(.bottom, 8)
            Text("Enjoy Leap?", bundle: .module)
                .foregroundStyle(Theme.secondaryText(contrast: colorSchemeContrast))
            HStack(spacing: 14) {
                Link(destination: donationURL) {
                    Text("You can buy me a coffee", bundle: .module)
                }
                Link(destination: feedbackURL) {
                    Text("Share your thoughts", bundle: .module)
                }
            }
            .buttonStyle(.link)
            Text("Thank you!", bundle: .module)
                .foregroundStyle(Theme.secondaryText(contrast: colorSchemeContrast))
        }
        .font(.callout)
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    OnboardingView()
}
