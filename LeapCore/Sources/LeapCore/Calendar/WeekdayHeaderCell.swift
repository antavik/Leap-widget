import SwiftUI

/// The edge columns export the guides the month title and year label align
/// to: the first glyph's leading edge, the last column's trailing edge.
struct WeekdayHeaderCell: View {
    let symbol: String
    let isWeekend: Bool
    let isFirstColumn: Bool
    let isLastColumn: Bool
    let metrics: Theme.Metrics

    var body: some View {
        let label = Text(verbatim: symbol)
            .font(.system(size: metrics.header, weight: .semibold))
            .foregroundStyle(isWeekend ? .secondary : .primary)

        Group {
            if isFirstColumn {
                label.alignmentGuide(.firstWeekdayColumn) { $0[.leading] }
                    .frame(maxWidth: .infinity)
            } else if isLastColumn {
                // The year label ends flush with the column's trailing edge.
                label.frame(maxWidth: .infinity)
                    .alignmentGuide(.lastWeekdayColumn) { $0[.trailing] }
            } else {
                label.frame(maxWidth: .infinity)
            }
        }
    }
}
