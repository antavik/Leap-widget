import Foundation

public func monthRow(containing date: Date,
                     offsets: [Int],
                     showYear: Bool,
                     builder: MonthModelBuilder) -> (models: [MonthModel], yearLabel: String?) {
    let models = offsets.map { builder.model(containing: date, offset: $0, today: date) }
    let currentIndex = offsets.firstIndex(of: 0) ?? 0
    guard showYear, models.indices.contains(currentIndex) else { return (models, nil) }

    let current = models[currentIndex]

    return (models, builder.usesGregorianYearNumbering
        ? yearLabel(forYear: current.year)
        : String(current.year))
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
