import Foundation

/// The months a widget shows and the year label for the current month.
/// `offsets` are relative to `date` in display order. The label uses the
/// current month's model when present, or the first model otherwise.
public func monthRow(containing date: Date,
                     offsets: [Int],
                     showYear: Bool,
                     builder: MonthModelBuilder) -> (models: [MonthModel], yearLabel: String?) {
    let models = offsets.map { builder.model(containing: date, offset: $0, today: date) }

    // A row showing no current month labels its first one: the single-month
    // widget set to a neighbour carries that neighbour's year.
    let current = models[offsets.firstIndex(of: 0) ?? 0]

    return (models, showYear ? yearLabel(forYear: current.year) : nil)
}

public func yearLabel(forYear year: Int) -> String {
    // The apostrophe form abbreviates a full year number (2026 -> \u{2019}26).
    // Era years are already short, and Reiwa 8 as \u{2019}08 would read as 2008.
    year >= 100 ? String(format: "\u{2019}%02d", year % 100) : String(year)
}
