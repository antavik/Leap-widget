import SwiftUI

struct WeekNumberCell: View {
    /// Gap on either side of the 1pt separator that trails the week-number
    /// column, so the full column footprint is `weekNumberColumnWidth + 7`.
    private static let separatorGap: CGFloat = 3

    let number: Int?
    var showsSeparator = true
    let metrics: Theme.Metrics

    var body: some View {
        HStack(spacing: Self.separatorGap) {
            Text(verbatim: number.map(String.init) ?? "")
                .font(.system(size: metrics.weekNumber, weight: .medium).monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: metrics.weekNumberColumnWidth, alignment: .trailing)
            Rectangle()
                .fill(.tertiary)
                .frame(width: 1)
                .padding(.vertical, -metrics.rowSpacing / 2)
                .opacity(showsSeparator ? 1 : 0)
        }
        .padding(.trailing, Self.separatorGap)
    }
}
