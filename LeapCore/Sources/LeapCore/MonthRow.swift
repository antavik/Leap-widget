import Foundation

/// Widget months and an optional year label.
/// `offsets` are relative to `date`; the label uses the current month or the first model.
public func monthRow(containing date: Date,
                     offsets: [Int],
                     showYear: Bool,
                     builder: MonthModelBuilder) -> (models: [MonthModel], yearLabel: String?) {
    let models = offsets.map { builder.model(containing: date, offset: $0, today: date) }

    // A row showing no current month labels its first one: the single-month
    // widget set to a neighbour carries that neighbour's year.
    let current = models[offsets.firstIndex(of: 0) ?? 0]

    guard showYear else { return (models, nil) }

    return (models, builder.usesGregorianYearNumbering
        ? yearLabel(forYear: current.year)
        : String(current.year))
}

/// Two-digit abbreviation of a Gregorian year, e.g. 2026 -> \u{2019}26.
public func yearLabel(forYear year: Int) -> String {
    String(format: "\u{2019}%02d", year % 100)
}
