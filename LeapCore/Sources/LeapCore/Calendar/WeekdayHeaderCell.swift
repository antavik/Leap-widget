import SwiftUI

/// The first column's glyph exports its leading edge as the
/// `firstWeekdayColumn` guide the month title aligns to.
struct WeekdayHeaderCell: View {
    let symbol: String
    let isWeekend: Bool
    let isFirstColumn: Bool
    let metrics: Theme.Metrics

    var body: some View {
        let label = Text(verbatim: symbol)
            .font(.system(size: metrics.header, weight: .semibold))
            .foregroundStyle(isWeekend ? .secondary : .primary)

        Group {
            if isFirstColumn {
                label.alignmentGuide(.firstWeekdayColumn) { $0[.leading] }
            } else {
                label
            }
        }
        .frame(maxWidth: .infinity)
    }
}
