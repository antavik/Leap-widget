import Foundation

public func monthRow(containing date: Date,
                     offsets: [Int],
                     showYear: Bool,
                     builder: MonthModelBuilder) -> (models: [MonthModel], yearLabel: String?) {
    let models = offsets.map { builder.model(containing: date, offset: $0, today: date) }
    let current = models[offsets.firstIndex(of: 0) ?? 0]
    guard showYear else { return (models, nil) }

    return (models, builder.usesGregorianYearNumbering
        ? yearLabel(forYear: current.year)
        : String(current.year))
}

public func yearLabel(forYear year: Int) -> String {
    String(format: "\u{2019}%02d", year % 100)
}
