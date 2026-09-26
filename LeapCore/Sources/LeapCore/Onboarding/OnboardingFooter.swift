import SwiftUI

struct OnboardingFooter: View {
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    let donationURL: URL
    let feedbackURL: URL

    var body: some View {
        VStack(spacing: Theme.Onboarding.footerSpacing) {
            Divider()
                .padding(.bottom, Theme.Onboarding.footerDividerGap)
            Text("Thank you for using Leap!", bundle: .module)
                .foregroundStyle(Theme.secondaryText(contrast: colorSchemeContrast))
            HStack(spacing: Theme.Onboarding.linkSpacing) {
                Link(destination: donationURL) {
                    Text("Buy me a coffee", bundle: .module)
                }
                Link(destination: feedbackURL) {
                    Text("Share your thoughts", bundle: .module)
                }
            }
            .buttonStyle(.link)
        }
        .font(.callout)
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity)
    }
}
