import SwiftUI

/// Aligns the month title and year label to the first and last weekday glyphs.
/// The title starts with the first glyph and the year ends with the last one,
/// keeping both inside the weekday columns across widget sizes.
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
