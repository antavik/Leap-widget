import SwiftUI

/// Widget layout family, decoupled from WidgetKit so the view stays previewable
/// and testable outside a widget process. Capacity per §3: small = 1 month,
/// medium = 2 side by side, large = 3 in a 2×2 grid, extra large = 3 in a row.
public enum WidgetLayoutFamily: Sendable {
    case small
    case medium
    case large
    case extraLarge

    public var capacity: Int {
        switch self {
        case .small: 1
        case .medium: 2
        case .large, .extraLarge: 3
        }
    }
}

/// Per-instance rendering configuration, mapped from the widget's intent (§4.2).
public struct WidgetConfig: Equatable, Sendable {
    public let span: Int
    public let companionPrevious: Bool
    public let options: MonthOptions

    public init(span: Int, companionPrevious: Bool, options: MonthOptions) {
        self.span = span
        self.companionPrevious = companionPrevious
        self.options = options
    }
}

/// Lays out one to three `MonthGridView`s for a family (§4.4) and renders the
/// `YearBoundaryDivider` between adjacent months of different years.
public struct MultiMonthView: View {
    private let models: [MonthModel]
    private let family: WidgetLayoutFamily
    private let metrics: Theme.Metrics

    public init(date: Date,
                family: WidgetLayoutFamily,
                config: WidgetConfig,
                calendar: Calendar = .autoupdatingCurrent) {
        let offsets = displayedOffsets(span: config.span,
                                       companionPrevious: config.companionPrevious,
                                       capacity: family.capacity)
        self.models = offsets.map {
            monthModel(containing: date,
                       offset: $0,
                       calendar: calendar,
                       today: date,
                       options: config.options)
        }
        self.family = family
        self.metrics = offsets.count > 1 ? Theme.compact : Theme.single
    }

    public var body: some View {
        switch models.count {
        case 1:
            MonthGridView(model: models[0], metrics: Theme.single)
        case 2:
            monthRow(models)
        default:
            if family == .extraLarge {
                monthRow(models)
            } else {
                largeGrid
            }
        }
    }

    /// Months side by side; a vertical divider replaces plain spacing at a
    /// year boundary.
    private func monthRow(_ models: [MonthModel]) -> some View {
        HStack(alignment: .top, spacing: 10) {
            ForEach(models.indices, id: \.self) { index in
                if index > 0 && models[index - 1].year != models[index].year {
                    YearBoundaryDivider(.vertical)
                }
                MonthGridView(model: models[index], metrics: metrics)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
    }

    /// Large family: previous + current on top, next bottom-leading (§4.4).
    private var largeGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            monthRow(Array(models[0...1]))
            if models[1].year != models[2].year {
                YearBoundaryDivider(.horizontal)
            }
            HStack(alignment: .top, spacing: 10) {
                MonthGridView(model: models[2], metrics: metrics)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                Color.clear
                    .frame(maxWidth: .infinity)
            }
        }
    }
}

#Preview("Dec | Jan — year boundary", traits: .fixedLayout(width: 360, height: 170)) {
    MultiMonthView(date: previewDate(2026, 12, 15),
                   family: .medium,
                   config: WidgetConfig(span: 2,
                                        companionPrevious: false,
                                        options: MonthOptions()),
                   calendar: previewCalendar())
    .padding(12)
}

#Preview("Three months — large", traits: .fixedLayout(width: 360, height: 380)) {
    MultiMonthView(date: previewDate(2026, 8, 12),
                   family: .large,
                   config: WidgetConfig(span: 3,
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
