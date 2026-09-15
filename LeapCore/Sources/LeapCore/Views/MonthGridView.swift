import SwiftUI

/// Aligns the month title with the first weekday header's glyph. A custom
/// alignment is needed because the centered header sits in a flexible column,
/// so no fixed inset stays correct across widget sizes.
private extension HorizontalAlignment {
    enum FirstWeekdayColumn: AlignmentID {
        static func defaultValue(in context: ViewDimensions) -> CGFloat {
            context[.leading]
        }
    }

    static let firstWeekdayColumn = HorizontalAlignment(FirstWeekdayColumn.self)
}

struct MonthGridView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    private let model: MonthModel
    private let metrics: Theme.Metrics

    init(model: MonthModel, metrics: Theme.Metrics = Theme.small) {
        self.model = model
        self.metrics = metrics
    }

    /// Gap on either side of the 1pt separator that trails the week-number
    /// column, so the full column footprint is `weekNumberColumnWidth + 7`.
    private static let separatorGap: CGFloat = 3

    var body: some View {
        let weekendColumns = model.weekendColumns

        VStack(alignment: .firstWeekdayColumn, spacing: 4) {
            titleText
                .foregroundStyle(.red)
                .alignmentGuide(.firstWeekdayColumn) { $0[.leading] }
            Grid(horizontalSpacing: 0, verticalSpacing: metrics.rowSpacing) {
                GridRow {
                    if model.weekNumbers != nil {
                        weekNumberCell(nil, showsSeparator: false)
                    }
                    ForEach(0..<7, id: \.self) { column in
                        headerCell(column, weekend: weekendColumns[column])
                    }
                }
                ForEach(0..<6, id: \.self) { row in
                    GridRow {
                        if let weekNumbers = model.weekNumbers {
                            weekNumberCell(rowHasVisibleDays(row) ? weekNumbers[row] : nil)
                        }
                        ForEach(0..<7, id: \.self) { column in
                            dayCell(model.weeks[row][column],
                                    weekend: weekendColumns[column])
                        }
                    }
                }
            }
        }
    }

    /// Month name and optional superscript month number in one `Text`.
    private var titleText: Text {
        let name = Text(verbatim: model.title)
            .font(.system(size: metrics.title, weight: .semibold))

        guard let label = model.monthNumberLabel else { return name }

        // Keep the gap in the glyph run so alignment stays on the title.
        return name + Text(verbatim: "\u{2009}" + label)
            .font(.system(size: metrics.monthNumber, weight: .semibold))
            .baselineOffset(metrics.monthNumberBaseline)
            .foregroundStyle(monthNumberTint)
    }

    private var monthNumberTint: AnyShapeStyle {
        colorScheme == .dark || colorSchemeContrast == .increased
            ? AnyShapeStyle(.red)
            : AnyShapeStyle(.red.opacity(0.55))
    }

    /// Weekday header cell; the first column's glyph exports its leading edge
    /// as the `firstWeekdayColumn` guide the month title aligns to.
    @ViewBuilder
    private func headerCell(_ column: Int, weekend: Bool) -> some View {
        let label = Text(model.weekdayHeaders[column])
            .font(.system(size: metrics.header, weight: .semibold))
            .foregroundStyle(weekend ? .secondary : .primary)

        if column == 0 {
            label
                .alignmentGuide(.firstWeekdayColumn) { $0[.leading] }
                .frame(maxWidth: .infinity)
        } else {
            label
                .frame(maxWidth: .infinity)
        }
    }

    /// A row made purely of adjacent-month days shows no week number when
    /// those days are hidden.
    private func rowHasVisibleDays(_ row: Int) -> Bool {
        model.showsOutsideDays || model.weeks[row].contains { !$0.isOutsideMonth }
    }

    @ViewBuilder
    private func dayCell(_ day: Day, weekend: Bool) -> some View {
        if day.isOutsideMonth && !model.showsOutsideDays {
            // Pin the placeholder to the standard row height. A bare
            // `Color.clear` would absorb extra vertical space and make rows
            // with hidden outside-month days taller than the others.
            Color.clear
                .frame(maxWidth: .infinity)
                .frame(height: metrics.rowHeight)
        } else if day.isToday {
            // `verbatim` keeps day numbers as ASCII digits in every locale,
            // matching the grid's fixed monospaced-digit metrics.
            Text(verbatim: "\(day.number)")
                .font(.system(size: metrics.day, weight: .semibold).monospacedDigit())
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: metrics.rowHeight)
                .background {
                    Circle()
                        .fill(.red)
                        .frame(width: metrics.todayCircle, height: metrics.todayCircle)
                }
        } else {
            Text(verbatim: "\(day.number)")
                .font(.system(size: metrics.day, weight: .semibold).monospacedDigit())
                .foregroundStyle(day.isOutsideMonth ? .tertiary
                                 : weekend ? .secondary : .primary)
                .frame(maxWidth: .infinity, minHeight: metrics.rowHeight)
        }
    }

    @ViewBuilder
    private func weekNumberCell(_ number: Int?,
                                showsSeparator: Bool = true) -> some View {
        HStack(spacing: Self.separatorGap) {
            Text(verbatim: number.map(String.init) ?? "")
                .font(.system(size: metrics.weekNumber, weight: .medium).monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: metrics.weekNumberColumnWidth, alignment: .trailing)
                .accessibilityHidden(number == nil)
            Rectangle()
                .fill(.tertiary)
                .frame(width: 1)
                .padding(.vertical, -metrics.rowSpacing / 2)
                .opacity(showsSeparator ? 1 : 0)
                .accessibilityHidden(true)
        }
        .padding(.trailing, Self.separatorGap)
    }
}

#Preview("August 2026 — Monday first", traits: .fixedLayout(width: 170, height: 170)) {
    MonthGridView(model: previewModel(firstWeekday: 2))
        .padding(12)
}

#Preview("Week numbers — dark", traits: .fixedLayout(width: 170, height: 170)) {
    MonthGridView(model: previewModel(firstWeekday: 2, showWeekNumbers: true))
        .padding(12)
        .preferredColorScheme(.dark)
}

#Preview("Roman month number", traits: .fixedLayout(width: 170, height: 170)) {
    MonthGridView(model: previewModel(firstWeekday: 2, monthNumberStyle: .roman))
        .padding(12)
}

private func previewModel(firstWeekday: Int, showWeekNumbers: Bool = false,
                          monthNumberStyle: MonthNumberStyle? = nil) -> MonthModel {
    var calendar = Calendar(identifier: .gregorian)
    calendar.locale = Locale(identifier: "en_US")

    let today = calendar.date(from: DateComponents(year: 2026, month: 8, day: 12))!

    return monthModel(containing: today,
                      offset: 0,
                      calendar: calendar,
                      today: today,
                      options: MonthOptions(firstWeekday: firstWeekday,
                                            showWeekNumbers: showWeekNumbers,
                                            monthNumberStyle: monthNumberStyle))
}
