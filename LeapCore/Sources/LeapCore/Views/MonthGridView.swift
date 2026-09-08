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

/// Renders one month with widget styling and a fixed six-row grid.
struct MonthGridView: View {
    @Environment(\.colorScheme) private var colorScheme

    private let model: MonthModel
    private let metrics: Theme.Metrics

    init(model: MonthModel, metrics: Theme.Metrics = Theme.small) {
        self.model = model
        self.metrics = metrics
    }

    private struct CellStyles {
        let bright: AnyShapeStyle
        let dim: AnyShapeStyle
        let faint: AnyShapeStyle
    }

    /// Dark mode uses pure white instead of `.primary` because desktop
    /// vibrancy dims the default label material. `faint` is for adjacent-month
    /// days: subtler than weekends but still legible.
    private var styles: CellStyles {
        colorScheme == .dark
            ? CellStyles(bright: AnyShapeStyle(.white),
                         dim: AnyShapeStyle(.white.opacity(0.7)),
                         faint: AnyShapeStyle(.white.opacity(0.4)))
            : CellStyles(bright: AnyShapeStyle(.primary),
                         dim: AnyShapeStyle(.secondary),
                         faint: AnyShapeStyle(.tertiary))
    }

    /// Gap on either side of the 1pt separator that trails the week-number
    /// column, so the full column footprint is `weekNumberColumnWidth + 7`.
    private static let separatorGap: CGFloat = 3

    var body: some View {
        let styles = self.styles
        let weekendColumns = model.weekendColumns

        VStack(alignment: .firstWeekdayColumn, spacing: 4) {
            titleText
                .foregroundStyle(.red)
                .alignmentGuide(.firstWeekdayColumn) { $0[.leading] }
                .accessibilityLabel(monthAccessibilityLabel)
            Grid(horizontalSpacing: 0, verticalSpacing: metrics.rowSpacing) {
                GridRow {
                    if model.weekNumbers != nil {
                        weekNumberCell(nil, styles: styles, showsSeparator: false)
                    }
                    ForEach(0..<7, id: \.self) { column in
                        headerCell(column, weekend: weekendColumns[column], styles: styles)
                    }
                }
                ForEach(0..<6, id: \.self) { row in
                    GridRow {
                        if let weekNumbers = model.weekNumbers {
                            weekNumberCell(rowHasVisibleDays(row) ? weekNumbers[row] : nil,
                                           styles: styles)
                        }
                        ForEach(0..<7, id: \.self) { column in
                            dayCell(model.weeks[row][column], styles: styles)
                        }
                    }
                }
            }
        }
    }

    /// Month name with an optional superscript month number.
    /// Keeping both in one `Text` preserves the title's
    /// `firstWeekdayColumn` alignment guide.
    private var titleText: Text {
        let name = Text(model.title)
            .font(.system(size: metrics.title, weight: .semibold))

        guard let label = model.monthNumberLabel else { return name }

        // Thin space: the gap belongs to the glyph run, so the alignment
        // guide keeps measuring from the title's own leading edge.
        return name + Text(verbatim: "\u{2009}" + label)
            .font(.system(size: metrics.monthNumber, weight: .semibold))
            .baselineOffset(metrics.monthNumberBaseline)
            .foregroundStyle(monthNumberTint)
    }

    /// The number reads as a subdued companion to the month name in full
    /// color, but vibrancy desaturates it further, so dark mode keeps it at
    /// the title's own tint to stay legible.
    private var monthNumberTint: AnyShapeStyle {
        colorScheme == .dark ? AnyShapeStyle(.red) : AnyShapeStyle(.red.opacity(0.55))
    }

    private var monthAccessibilityLabel: Text {
        model.monthNumberLabel == nil
            ? Text(model.title)
            : Text("\(model.title), month \(model.monthNumber)")
    }

    /// Weekday header cell; the first column's glyph exports its leading edge
    /// as the `firstWeekdayColumn` guide the month title aligns to.
    @ViewBuilder
    private func headerCell(_ column: Int, weekend: Bool, styles: CellStyles) -> some View {
        let label = Text(model.weekdayHeaders[column])
            .font(.system(size: metrics.header, weight: .semibold))
            .foregroundStyle(weekend ? styles.dim : styles.bright)

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
    private func dayCell(_ day: Day, styles: CellStyles) -> some View {
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
                .accessibilityLabel("\(day.number), today")
        } else {
            Text(verbatim: "\(day.number)")
                .font(.system(size: metrics.day, weight: .semibold).monospacedDigit())
                .foregroundStyle(day.isOutsideMonth ? styles.faint
                                 : day.isWeekend ? styles.dim : styles.bright)
                .frame(maxWidth: .infinity, minHeight: metrics.rowHeight)
        }
    }

    @ViewBuilder
    private func weekNumberCell(_ number: Int?, styles: CellStyles,
                                showsSeparator: Bool = true) -> some View {
        HStack(spacing: Self.separatorGap) {
            Text(verbatim: number.map(String.init) ?? "")
                .font(.system(size: metrics.weekNumber, weight: .medium).monospacedDigit())
                .foregroundStyle(styles.dim)
                .frame(width: metrics.weekNumberColumnWidth, alignment: .trailing)
            Rectangle()
                .fill(styles.faint)
                .frame(width: 1)
                .padding(.vertical, -metrics.rowSpacing / 2)
                .opacity(showsSeparator ? 1 : 0)
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
