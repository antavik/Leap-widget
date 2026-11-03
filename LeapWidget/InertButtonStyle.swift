import SwiftUI

/// No press feedback – the surface should feel inert, not interactive.
struct InertButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
    }
}
