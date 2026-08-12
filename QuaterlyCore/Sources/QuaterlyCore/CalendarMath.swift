import Foundation

/// Builds the display model for one month (§4.3).
///
/// - Parameters:
///   - date: any date inside the reference month (usually the timeline entry date).
///   - offset: months relative to the reference month (-1, 0, +1).
///   - calendar: base calendar, normally `Calendar.autoupdatingCurrent`.
///   - today: the date whose day gets the "today" marker; only ever honored in
///     the offset-0 month.
///   - options: first-weekday override and week-number switch.
public func monthModel(containing date: Date,
                       offset: Int,
                       calendar: Calendar,
                       today: Date,
                       options: MonthOptions) -> MonthModel {
    var effective = calendar
    if let override = options.firstWeekday {
        effective.firstWeekday = override
    }
    if effective.firstWeekday == 2 {
        // Monday-first layouts number weeks ISO-8601 style, matching Apple Calendar.
        effective.minimumDaysInFirstWeek = 4
    }

    let shifted = effective.date(byAdding: .month, value: offset, to: date)!
    let components = effective.dateComponents([.year, .month], from: shifted)
    let monthStart = effective.date(from: components)!
    let year = components.year!
    let month = components.month!
    let dayCount = effective.range(of: .day, in: .month, for: monthStart)!.count

    let title = effective.standaloneMonthSymbols[month - 1].uppercased(with: effective.locale)

    let weekdaySymbols = effective.veryShortStandaloneWeekdaySymbols
    let firstIndex = effective.firstWeekday - 1
    let headers = (0..<7).map { weekdaySymbols[(firstIndex + $0) % 7] }

    let weekdayOfFirst = effective.component(.weekday, from: monthStart)
    let leadingBlanks = (weekdayOfFirst - effective.firstWeekday + 7) % 7

    var cells: [(day: Day, date: Date)?] = Array(repeating: nil, count: leadingBlanks)
    for number in 1...dayCount {
        let dayDate = effective.date(byAdding: .day, value: number - 1, to: monthStart)!
        let day = Day(number: number,
                      isToday: offset == 0 && effective.isDate(dayDate, inSameDayAs: today),
                      isWeekend: effective.isDateInWeekend(dayDate))
        cells.append((day, dayDate))
    }
    while cells.count % 7 != 0 {
        cells.append(nil)
    }

    var weeks: [[Day?]] = []
    var weekNumbers: [Int]? = options.showWeekNumbers ? [] : nil
    for rowStart in stride(from: 0, to: cells.count, by: 7) {
        let row = Array(cells[rowStart..<(rowStart + 7)])
        weeks.append(row.map { $0?.day })
        if options.showWeekNumbers {
            // A row is one calendar week, so any concrete day yields its number.
            let anchor = row.compactMap { $0?.date }.first!
            weekNumbers?.append(effective.component(.weekOfYear, from: anchor))
        }
    }

    return MonthModel(title: title,
                      year: year,
                      weekdayHeaders: headers,
                      weeks: weeks,
                      weekNumbers: weekNumbers)
}

/// Month offsets to render for a span, clamped to the family's capacity (§3):
/// the current month always survives; the past is dropped before the future.
public func displayedOffsets(span: Int, companionPrevious: Bool, capacity: Int) -> [Int] {
    var offsets: [Int]
    switch span {
    case ...1: offsets = [0]
    case 2: offsets = companionPrevious ? [-1, 0] : [0, 1]
    default: offsets = [-1, 0, 1]
    }
    while offsets.count > max(capacity, 1) {
        if offsets.first! < 0 {
            offsets.removeFirst()
        } else {
            offsets.removeLast()
        }
    }
    return offsets
}

/// Timeline entry dates: now plus the next two midnights (§4.6). Midnights come
/// from `Calendar`, so DST transitions stay aligned.
public func timelineDates(from now: Date, calendar: Calendar) -> [Date] {
    let todayStart = calendar.startOfDay(for: now)
    let midnights = (1...2).compactMap { calendar.date(byAdding: .day, value: $0, to: todayStart) }
    return [now] + midnights
}
