import SwiftUI

struct MonthGridView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    private let model: MonthModel
    private let metrics: Theme.Metrics
    private let yearLabel: String?

    init(model: MonthModel, metrics: Theme.Metrics = Theme.small, yearLabel: String? = nil) {
        self.model = model
        self.metrics = metrics
        self.yearLabel = yearLabel
    }

    var body: some View {
        let weekendColumns = model.weekendColumns

        VStack(alignment: .firstWeekdayColumn, spacing: 4) {
            Text(title)
                .foregroundStyle(.red)
                .alignmentGuide(.firstWeekdayColumn) { $0[.leading] }
            Grid(horizontalSpacing: 0, verticalSpacing: metrics.rowSpacing) {
                GridRow {
                    if model.weekNumbers != nil {
                        WeekNumberCell(number: nil, showsSeparator: false, metrics: metrics)
                    }
                    ForEach(0..<7, id: \.self) { column in
                        WeekdayHeaderCell(symbol: model.weekdayHeaders[column],
                                          isWeekend: weekendColumns[column],
                                          isFirstColumn: column == model.weekdayHeaders.indices.first,
                                          isLastColumn: column == model.weekdayHeaders.indices.last,
                                          metrics: metrics)
                    }
                }
                ForEach(0..<6, id: \.self) { row in
                    GridRow {
                        if let weekNumbers = model.weekNumbers {
                            WeekNumberCell(number: rowHasVisibleDays(row) ? weekNumbers[row] : nil,
                                           metrics: metrics)
                        }
                        ForEach(0..<7, id: \.self) { column in
                            DayCell(day: model.weeks[row][column],
                                    isWeekend: weekendColumns[column],
                                    showsOutsideDays: model.showsOutsideDays,
                                    metrics: metrics)
                        }
                    }
                }
            }
        }
        .overlay(alignment: Alignment(horizontal: .lastWeekdayColumn, vertical: .top)) {
            if let yearLabel {
                Text(yearLabel)
                    .font(.system(size: metrics.title, weight: .bold))
                    .foregroundStyle(.red)
            }
        }
    }

    /// Month name and optional superscript month number in one glyph run.
    private var title: AttributedString {
        var name = AttributedString(model.title)
        name.swiftUI.font = .system(size: metrics.title, weight: .semibold)

        guard let label = model.monthNumberLabel else { return name }

        // Keep the gap in the glyph run so alignment stays on the title.
        var number = AttributedString("\u{2009}" + label)
        number.swiftUI.font = .system(size: metrics.monthNumber, weight: .semibold)
        number.swiftUI.baselineOffset = metrics.monthNumberBaseline
        number.swiftUI.foregroundColor = Theme.monthNumberTint(colorScheme: colorScheme,
                                                               contrast: colorSchemeContrast)

        return name + number
    }

    /// A row made purely of adjacent-month days shows no week number when
    /// those days are hidden.
    private func rowHasVisibleDays(_ row: Int) -> Bool {
        model.showsOutsideDays || model.weeks[row].contains { !$0.isOutsideMonth }
    }
}

#Preview("August 2026 – Monday first", traits: .fixedLayout(width: 170, height: 170)) {
    MonthGridView(model: previewModel(firstWeekday: 2))
        .padding(12)
}

#Preview("Week numbers – dark", traits: .fixedLayout(width: 170, height: 170)) {
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
