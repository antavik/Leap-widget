import Foundation

/// Builds the display model for one month.
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
    let leadingCount = (weekdayOfFirst - effective.firstWeekday + 7) % 7

    // Leading cells show the previous month's tail; its length is all the
    // date math those cells need.
    let previousMonthStart = effective.date(byAdding: .month, value: -1, to: monthStart)!
    let previousDayCount = effective.range(of: .day, in: .month, for: previousMonthStart)!.count

    // The today marker reduces to one day-number comparison: it can only sit
    // in the offset-0 month, and only when `today` falls inside that month.
    let todayComponents = effective.dateComponents([.year, .month, .day], from: today)
    let todayNumber: Int? = (offset == 0 && todayComponents.year == year
                             && todayComponents.month == month)
        ? todayComponents.day : nil

    // Weekends are a weekday property (`isDateInWeekend` is locale-driven but
    // weekday-based), and each grid column holds one weekday — 7 checks cover
    // all 42 cells. Index i = days after the month's first day, whose column
    // is `leadingCount`; grid columns rotate from there.
    let weekendFromFirstDay = (0..<7).map { dayIndex in
        effective.isDateInWeekend(
            effective.date(byAdding: .day, value: dayIndex, to: monthStart)!)
    }

    // Always six full rows: leading/trailing cells carry adjacent-month days
    // so 5- and 6-week months keep identical geometry. Day numbers derive
    // arithmetically from the three month lengths — no per-cell `Date`.
    var weeks: [[Day]] = []
    weeks.reserveCapacity(6)
    var weekNumbers: [Int]? = options.showWeekNumbers ? [] : nil
    for row in 0..<6 {
        var days: [Day] = []
        days.reserveCapacity(7)
        for column in 0..<7 {
            let index = row * 7 + column
            let dayOffset = index - leadingCount
            let outside = dayOffset < 0 || dayOffset >= dayCount
            let number = dayOffset < 0 ? previousDayCount + dayOffset + 1
                : dayOffset < dayCount ? dayOffset + 1
                : dayOffset - dayCount + 1
            days.append(Day(number: number,
                            isToday: !outside && number == todayNumber,
                            isWeekend: weekendFromFirstDay[(column - leadingCount + 7) % 7],
                            isOutsideMonth: outside))
        }
        weeks.append(days)

        if options.showWeekNumbers {
            // A row is one calendar week, so its first day yields the number.
            let rowFirstDate = effective.date(byAdding: .day,
                                              value: row * 7 - leadingCount,
                                              to: monthStart)!
            weekNumbers?.append(effective.component(.weekOfYear, from: rowFirstDate))
        }
    }

    return MonthModel(title: title,
                      year: year,
                      weekdayHeaders: headers,
                      weeks: weeks,
                      weekNumbers: weekNumbers,
                      showsOutsideDays: options.showOutsideDays)
}

/// Month offsets to render (0 = current) for the requested span: a 2-month
/// span pairs the current month with the previous or next one, larger spans
/// give `[-1, 0, 1]`. Clamped to `capacity`, dropping past months before
/// future ones so offset 0 always survives.
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

/// Timeline entry dates: now plus the next two midnights. Midnights come
/// from `Calendar`, so DST transitions stay aligned.
public func timelineDates(from now: Date, calendar: Calendar) -> [Date] {
    let todayStart = calendar.startOfDay(for: now)
    let midnights = (1...2).compactMap { calendar.date(byAdding: .day, value: $0, to: todayStart) }

    return [now] + midnights
}
