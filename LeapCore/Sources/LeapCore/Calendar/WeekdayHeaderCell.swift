import SwiftUI

/// The edge columns export the guides the month title and year label align
/// to: the first glyph's leading edge, the last glyph's trailing edge.
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
                label.alignmentGuide(.lastWeekdayColumn) { $0[.trailing] }
                    .frame(maxWidth: .infinity)
            } else {
                label.frame(maxWidth: .infinity)
            }
        }
    }
}
