import Foundation

struct OnboardingStep: Identifiable {
    let symbol: String
    let title: LocalizedStringResource
    let text: LocalizedStringResource

    var id: String { symbol }
}
