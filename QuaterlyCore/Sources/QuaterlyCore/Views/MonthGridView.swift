import SwiftUI

/// One month rendered to the Apple-widget spec (§4.4): red uppercased title,
/// very-short weekday header, blank leading/trailing cells, gray weekends,
/// filled red circle on today. The grid always reserves six rows so 5- and
/// 6-week months keep identical geometry (§4.10).
public struct MonthGridView: View {
    private let model: MonthModel
    private let metrics: Theme.Metrics

    public init(model: MonthModel, metrics: Theme.Metrics = Theme.single) {
        self.model = model
        self.metrics = metrics
    }

    public var body: some View {
        let weekendColumns = model.weekendColumns
        VStack(alignment: .leading, spacing: 4) {
            Text(model.title)
                .font(.system(size: metrics.title, weight: .bold))
                .foregroundStyle(.red)
            Grid(horizontalSpacing: 0, verticalSpacing: metrics.rowSpacing) {
                GridRow {
                    if model.weekNumbers != nil {
                        weekNumberCell(nil)
                    }
                    ForEach(0..<7, id: \.self) { column in
                        Text(model.weekdayHeaders[column])
                            .font(.system(size: metrics.header, weight: .semibold))
                            .foregroundStyle(weekendColumns[column] ? AnyShapeStyle(.secondary)
                                                                    : AnyShapeStyle(.primary))
                            .frame(maxWidth: .infinity)
                    }
                }
                ForEach(0..<6, id: \.self) { row in
                    GridRow {
                        if let weekNumbers = model.weekNumbers {
                            weekNumberCell(row < weekNumbers.count ? weekNumbers[row] : nil)
                        }
                        ForEach(0..<7, id: \.self) { column in
                            dayCell(row < model.weeks.count ? model.weeks[row][column] : nil)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func dayCell(_ day: Day?) -> some View {
        if let day {
            Text("\(day.number)")
                .font(.system(size: metrics.day, weight: .semibold).monospacedDigit())
                .foregroundStyle(foregroundStyle(for: day))
                .frame(maxWidth: .infinity, minHeight: metrics.todayCircle)
                .background {
                    if day.isToday {
                        Circle()
                            .fill(.red)
                            .frame(width: metrics.todayCircle, height: metrics.todayCircle)
                    }
                }
        } else {
            Color.clear
                .frame(maxWidth: .infinity, minHeight: metrics.todayCircle)
        }
    }

    private func foregroundStyle(for day: Day) -> AnyShapeStyle {
        if day.isToday {
            AnyShapeStyle(.white)
        } else if day.isWeekend {
            AnyShapeStyle(.secondary)
        } else {
            AnyShapeStyle(.primary)
        }
    }

    @ViewBuilder
    private func weekNumberCell(_ number: Int?) -> some View {
        Text(number.map(String.init) ?? "")
            .font(.system(size: metrics.weekNumber, weight: .medium).monospacedDigit())
            .foregroundStyle(.secondary)
            .frame(width: metrics.weekNumberColumnWidth, alignment: .trailing)
            .padding(.trailing, 2)
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

private func previewModel(firstWeekday: Int, showWeekNumbers: Bool = false) -> MonthModel {
    var calendar = Calendar(identifier: .gregorian)
    calendar.locale = Locale(identifier: "en_US")
    let today = calendar.date(from: DateComponents(year: 2026, month: 8, day: 12))!
    return monthModel(containing: today,
                      offset: 0,
                      calendar: calendar,
                      today: today,
                      options: MonthOptions(firstWeekday: firstWeekday,
                                            showWeekNumbers: showWeekNumbers))
}
