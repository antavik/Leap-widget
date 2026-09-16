import SwiftUI

public struct MultiMonthView: View {
    private let models: [MonthModel]
    private let metrics: Theme.Metrics
    private let yearLabel: String?

    public init(models: [MonthModel], yearLabel: String?) {
        self.models = models
        self.metrics = models.count == 1 ? Theme.small : Theme.medium
        self.yearLabel = yearLabel
    }

    public var body: some View {
        Group {
            if models.count == 1 {
                MonthGridView(model: models[0], metrics: metrics)
            } else {
                sideBySideMonths
            }
        }
        .overlay(alignment: .topTrailing) {
            if let yearLabel {
                Text(yearLabel)
                    .font(.system(size: metrics.title, weight: .bold))
                    .foregroundStyle(.red)
                    .padding(.trailing, metrics.yearLabelTrailingInset)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: spokenSummary(of: models)))
    }

    private var sideBySideMonths: some View {
        HStack(alignment: .top, spacing: 10) {
            ForEach(models.indices, id: \.self) { index in
                MonthGridView(model: models[index], metrics: metrics)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
    }
}

#Preview("Aug | Sep \u{2014} week numbers", traits: .fixedLayout(width: 360, height: 170)) {
    let row = monthRow(containing: previewDate(2026, 8, 12),
                       offsets: [0, 1],
                       showYear: true,
                       builder: MonthModelBuilder(
                           calendar: previewCalendar(),
                           options: MonthOptions(showWeekNumbers: true)))

    MultiMonthView(models: row.models, yearLabel: row.yearLabel)
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
