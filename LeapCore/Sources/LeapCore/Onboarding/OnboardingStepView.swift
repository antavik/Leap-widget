import SwiftUI

struct OnboardingStepView: View {
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    let step: OnboardingStep
    let number: Int
    let total: Int

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: step.symbol)
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: headline)
                    .font(.headline)
                Text(step.text)
                    .font(.callout)
                    .foregroundStyle(Theme.secondaryText(contrast: colorSchemeContrast))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: spokenStep))
    }

    private var headline: String {
        String(localized: "\(number). \(String(localized: step.title))",
               bundle: .module,
               comment: "Numbered onboarding step headline")
    }

    private var spokenStep: String {
        String(localized: "Step \(number) of \(total). \(String(localized: step.title)). \(String(localized: step.text))",
               bundle: .module,
               comment: "VoiceOver label for one onboarding step")
    }
}
