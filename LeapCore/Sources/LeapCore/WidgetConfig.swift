import Foundation

public enum WidgetLayoutFamily: Sendable {
    case small
    case medium

    public var capacity: Int {
        switch self {
        case .small: 1
        case .medium: 2
        }
    }
}

public struct WidgetConfig: Equatable, Sendable {
    public let span: Int
    public let companionPrevious: Bool
    public let showYear: Bool
    public let options: MonthOptions

    public init(span: Int, companionPrevious: Bool, showYear: Bool = true,
                options: MonthOptions) {
        self.span = span
        self.companionPrevious = companionPrevious
        self.showYear = showYear
        self.options = options
    }
}

public func monthModels(containing date: Date,
                        family: WidgetLayoutFamily,
                        config: WidgetConfig,
                        calendar: Calendar = .autoupdatingCurrent) -> [MonthModel] {
    displayedOffsets(span: config.span,
                     companionPrevious: config.companionPrevious,
                     capacity: family.capacity)
        .map {
            monthModel(containing: date,
                       offset: $0,
                       calendar: calendar,
                       today: date,
                       options: config.options)
        }
}

public func yearLabel(forYear year: Int) -> String {
    String(format: "\u{2019}%02d", year % 100)
}

public func currentYearLabel(for date: Date,
                             config: WidgetConfig,
                             calendar: Calendar = .autoupdatingCurrent) -> String? {
    config.showYear
        ? yearLabel(forYear: calendar.component(.year, from: date))
        : nil
}
