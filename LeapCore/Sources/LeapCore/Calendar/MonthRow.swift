import Foundation

public struct YearLabel: Equatable, Sendable {
    public let text: String
    /// True for the label of the offset-0 (reference) month; when the row has no
    /// offset-0 month (small widget next/previous), index 0 is the reference.
    /// The current label keeps the accent color; the other year's label on a
    /// December–January row renders like week numbers.
    public let isCurrent: Bool

    public init(text: String, isCurrent: Bool) {
        self.text = text
        self.isCurrent = isCurrent
    }
}

/// `yearLabels` is index-parallel to `models`. Offsets are consecutive months, so a
/// year change within a row is the December–January case (other calendars roll at
/// their own new year); then every month is labeled with its own year. Otherwise
/// only the last month carries the reference year.
public func monthRow(containing date: Date,
                     offsets: [Int],
                     showYear: Bool,
                     builder: MonthModelBuilder) -> (models: [MonthModel], yearLabels: [YearLabel?]) {
    let models = offsets.map { builder.model(containing: date, offset: $0, today: date) }
    let currentIndex = offsets.firstIndex(of: 0) ?? 0
    var labels = [YearLabel?](repeating: nil, count: models.count)
    guard showYear, models.indices.contains(currentIndex) else { return (models, labels) }

    func text(forYear year: Int) -> String {
        builder.usesGregorianYearNumbering ? yearLabel(forYear: year) : String(year)
    }

    let currentYear = models[currentIndex].year

    if models.contains(where: { $0.year != currentYear }) {
        for (index, model) in models.enumerated() {
            labels[index] = YearLabel(text: text(forYear: model.year), isCurrent: model.year == currentYear)
        }
    } else {
        labels[models.count - 1] = YearLabel(text: text(forYear: currentYear), isCurrent: true)
    }

    return (models, labels)
}

public func yearLabel(forYear year: Int) -> String {
    "\u{2019}" + (year % 100).formatted(.number
        .precision(.integerLength(2))
        .grouping(.never)
        .locale(Locale(identifier: "en_US_POSIX")))
}

public func spokenSummary(of models: [MonthModel],
                          locale: Locale = .autoupdatingCurrent) -> String {
    if let today = models.first(where: \.containsToday) { return today.spokenSummary }

    return models.map(\.spokenSummary).formatted(.list(type: .and).locale(locale))
}
