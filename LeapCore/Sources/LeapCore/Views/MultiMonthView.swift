import SwiftUI

public struct MultiMonthView: View {
    private let models: [MonthModel]
    private let metrics: Theme.Metrics
    private let yearLabel: String?

    public init(models: [MonthModel], yearLabel: String?) {
        self.models = models
        self.metrics = Theme.compact
        self.yearLabel = yearLabel
    }

    public init(date: Date,
                family: WidgetLayoutFamily,
                config: WidgetConfig,
                calendar: Calendar = .autoupdatingCurrent) {
        self.init(models: monthModels(containing: date, family: family,
                                      config: config, calendar: calendar),
                  yearLabel: currentYearLabel(for: date, config: config, calendar: calendar))
    }

    public var body: some View {
        Group {
            if models.count == 1 {
                MonthGridView(model: models[0], metrics: metrics)
            } else {
                monthRow
            }
        }
        .overlay(alignment: .topTrailing) {
            if let yearLabel {
                Text(yearLabel)
                    .font(.system(size: metrics.title, weight: .bold))
                    .foregroundStyle(.red)
                    .padding(.trailing, metrics.titleLeadingInset)
            }
        }
    }

    private var monthRow: some View {
        HStack(alignment: .top, spacing: 10) {
            ForEach(models.indices, id: \.self) { index in
                MonthGridView(model: models[index], metrics: metrics)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
    }
}

#Preview("Aug | Sep — week numbers", traits: .fixedLayout(width: 360, height: 170)) {
    MultiMonthView(date: previewDate(2026, 8, 12),
                   family: .medium,
                   config: WidgetConfig(span: 2,
                                        companionPrevious: false,
                                        options: MonthOptions(showWeekNumbers: true)),
                   calendar: previewCalendar())
    .padding(12)
}

private func previewCalendar() -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.locale = Locale(identifier: "en_US")
    calendar.firstWeekday = 2

    return calendar
}

private func previewDate(_ year: Int, _ month: Int, _ day: Int) -> Date {
    previewCalendar().date(from: DateComponents(year: year, month: month, day: day))!
}
