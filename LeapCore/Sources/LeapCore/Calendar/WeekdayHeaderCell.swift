import SwiftUI

/// The first and last columns' glyphs export the `firstWeekdayColumn` and
/// `lastWeekdayColumn` guides the month title and year label align to.
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
                label.alignmentGuide(.lastWeekdayColumn) { $0[.trailing] }
            } else {
                label
            }
        }
        .frame(maxWidth: .infinity)
    }
}
