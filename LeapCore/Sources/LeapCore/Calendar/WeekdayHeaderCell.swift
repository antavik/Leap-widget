import SwiftUI

/// The edge columns export the guides the month title and year label align
/// to: the first glyph's leading edge, the last column's centre.
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
            } else if isLastColumn {
                // The glyph sits centred in its column-wide frame, so its
                // centre is the column's centre – where the year label centres.
                label.alignmentGuide(.lastWeekdayColumn) { $0[HorizontalAlignment.center] }
            } else {
                label
            }
        }
        .frame(maxWidth: .infinity)
    }
}
