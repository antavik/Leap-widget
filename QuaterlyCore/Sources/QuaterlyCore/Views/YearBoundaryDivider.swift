import SwiftUI
import AppKit

/// Marks the crossing between adjacent displayed months of different years
/// (§4.4). v1 renders a thin separator line; a future graphical asset replaces
/// the body of this view without touching any layout (§9).
public struct YearBoundaryDivider: View {
    public enum Orientation: Sendable {
        /// Between vertically stacked months.
        case horizontal
        /// Between side-by-side months.
        case vertical
    }

    private let orientation: Orientation

    public init(_ orientation: Orientation) {
        self.orientation = orientation
    }

    public var body: some View {
        switch orientation {
        case .horizontal:
            Rectangle()
                .fill(Color(nsColor: .separatorColor))
                .frame(height: 1)
                .padding(.horizontal, 6)
        case .vertical:
            Rectangle()
                .fill(Color(nsColor: .separatorColor))
                .frame(width: 1)
                .padding(.vertical, 6)
        }
    }
}
