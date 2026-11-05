import SwiftUI

/// Custom guides tying the month title and year label to the first and last
/// weekday columns. The title leads on the first column's glyph; the year
/// label centres on the last column. The header columns are flexible, so no
/// fixed inset stays correct across widget sizes.
extension HorizontalAlignment {
    enum FirstWeekdayColumn: AlignmentID {
        static func defaultValue(in context: ViewDimensions) -> CGFloat {
            context[.leading]
        }
    }

    static let firstWeekdayColumn = HorizontalAlignment(FirstWeekdayColumn.self)

    enum LastWeekdayColumn: AlignmentID {
        static func defaultValue(in context: ViewDimensions) -> CGFloat {
            context[.trailing]
        }
    }

    static let lastWeekdayColumn = HorizontalAlignment(LastWeekdayColumn.self)
}
