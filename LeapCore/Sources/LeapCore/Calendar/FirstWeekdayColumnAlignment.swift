import SwiftUI

/// Aligns the month title with the first weekday header's glyph. A custom
/// alignment is needed because the centered header sits in a flexible column,
/// so no fixed inset stays correct across widget sizes.
extension HorizontalAlignment {
    enum FirstWeekdayColumn: AlignmentID {
        static func defaultValue(in context: ViewDimensions) -> CGFloat {
            context[.leading]
        }
    }

    static let firstWeekdayColumn = HorizontalAlignment(FirstWeekdayColumn.self)
}
