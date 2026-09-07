import Foundation

/// Builds month models for a widget reload, caching shared calendar state.
/// Gregorian-family calendars (`.gregorian`, `.iso8601`) use `Civil` for
/// grid arithmetic and `Calendar` only for time-zone anchoring. Other
/// calendars fall back to `monthModelUsingCalendar`.
public struct MonthModelBuilder: Sendable {
    private let calendar: Calendar
    private let options: MonthOptions
    private let firstWeekday: Int
    private let minimumDaysInFirstWeek: Int
    private let monthTitles: [String]
    private let weekdayHeaders: [String]
    private let weekendByWeekday: [Bool]
    private let usesCivilArithmetic: Bool

    public init(calendar: Calendar, options: MonthOptions) {
        var effective = calendar
        applyFirstWeekday(options.firstWeekday, to: &effective)
        self.calendar = effective

        self.options = options
        self.firstWeekday = effective.firstWeekday
        self.minimumDaysInFirstWeek = effective.minimumDaysInFirstWeek
        self.usesCivilArithmetic = effective.identifier == .gregorian
            || effective.identifier == .iso8601

        let locale = effective.locale
        self.monthTitles = effective.standaloneMonthSymbols.map {
            $0.uppercased(with: locale)
        }

        let weekdaySymbols = effective.veryShortStandaloneWeekdaySymbols
        let firstIndex = effective.firstWeekday - 1

        self.weekdayHeaders = (0..<7).map { weekdaySymbols[(firstIndex + $0) % 7] }

        // Weekend status depends only on weekday, so probing seven days fills
        // the whole map safely for any calendar identifier.
        var weekend = [Bool](repeating: false, count: 7)
        var probe = Date(timeIntervalSince1970: 1_704_628_800)   // 2024-01-07 12:00 GMT
        for _ in 0..<7 {
            weekend[effective.component(.weekday, from: probe) - 1]
                = effective.isDateInWeekend(probe)
            probe = effective.date(byAdding: .day, value: 1, to: probe)
                ?? probe.addingTimeInterval(86_400)
        }
        self.weekendByWeekday = weekend
    }

    public func model(containing date: Date, offset: Int, today: Date) -> MonthModel {
        guard usesCivilArithmetic else {
            return monthModelUsingCalendar(containing: date, offset: offset,
                                           calendar: calendar, today: today,
                                           options: options)
        }

        // The only per-month ICU work: anchoring the dates as civil
        // (year, month, day) in the calendar's time zone.
        let anchor = calendar.dateComponents([.year, .month, .day], from: date)
        let todayAnchor = today == date
            ? anchor : calendar.dateComponents([.year, .month, .day], from: today)

        // Month shift without date math: months since year zero, floored back
        // into (year, month).
        let monthIndex = anchor.year! * 12 + (anchor.month! - 1) + offset
        let year = monthIndex >= 0 ? monthIndex / 12 : (monthIndex - 11) / 12
        let month = monthIndex - year * 12 + 1

        let dayCount = Civil.daysInMonth(year, month)
        let previousDayCount = month == 1 ? Civil.daysInMonth(year - 1, 12)
            : Civil.daysInMonth(year, month - 1)
        let leadingCount = Civil.positiveMod(Civil.weekday(year, month, 1) - firstWeekday, 7)

        let todayNumber: Int? = (offset == 0 && todayAnchor.year == year
                                 && todayAnchor.month == month)
            ? todayAnchor.day : nil

        // Always six full rows: leading/trailing cells carry adjacent-month
        // days so 5- and 6-week months keep identical geometry. Day numbers
        // derive arithmetically from the three month lengths — no per-cell
        // `Date`.
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
                                isWeekend: weekendByWeekday[(firstWeekday - 1 + column) % 7],
                                isOutsideMonth: outside))
            }
            weeks.append(days)

            if options.showWeekNumbers {
                // A row is one calendar week; its first day, normalized into
                // its own month, yields the number.
                var (weekYear, weekMonth, weekDay) = (year, month, row * 7 - leadingCount + 1)
                if weekDay < 1 {
                    (weekYear, weekMonth) = month == 1 ? (year - 1, 12) : (year, month - 1)
                    weekDay += Civil.daysInMonth(weekYear, weekMonth)
                } else if weekDay > dayCount {
                    (weekYear, weekMonth) = month == 12 ? (year + 1, 1) : (year, month + 1)
                    weekDay -= dayCount
                }
                weekNumbers?.append(Civil.weekOfYear(weekYear, weekMonth, weekDay,
                                                     firstWeekday: firstWeekday,
                                                     minimumDays: minimumDaysInFirstWeek))
            }
        }

        return MonthModel(title: monthTitles[month - 1],
                          year: year,
                          monthNumber: month,
                          monthNumberLabel: options.monthNumberStyle
                              .flatMap { $0.label(forMonth: month) },
                          weekdayHeaders: weekdayHeaders,
                          weeks: weeks,
                          weekNumbers: weekNumbers,
                          showsOutsideDays: options.showOutsideDays)
    }
}

/// Builds the display model for one month.
///
/// Use this for one-off builds; reuse `MonthModelBuilder` for multiple months.
/// - Parameters:
///   - date: any date in the reference month.
///   - offset: months relative to the reference month (-1, 0, +1).
///   - calendar: base calendar, usually `Calendar.autoupdatingCurrent`.
///   - today: marks its day only in the offset-0 month.
///   - options: first-weekday override and week-number setting.
public func monthModel(containing date: Date,
                       offset: Int,
                       calendar: Calendar,
                       today: Date,
                       options: MonthOptions) -> MonthModel {
    MonthModelBuilder(calendar: calendar, options: options)
        .model(containing: date, offset: offset, today: today)
}

/// `Calendar`-only month build: the fallback for non-Gregorian identifiers
/// and the oracle the parity tests hold the arithmetic path against.
func monthModelUsingCalendar(containing date: Date,
                             offset: Int,
                             calendar: Calendar,
                             today: Date,
                             options: MonthOptions) -> MonthModel {
    var effective = calendar
    applyFirstWeekday(options.firstWeekday, to: &effective)

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

    // Weekend status depends only on weekday, so seven checks cover the grid.
    let weekendFromFirstDay = (0..<7).map { dayIndex in
        effective.isDateInWeekend(
            effective.date(byAdding: .day, value: dayIndex, to: monthStart)!)
    }

    // Always render six rows, filling edge cells from adjacent months.
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
                      monthNumber: month,
                      monthNumberLabel: options.monthNumberStyle
                          .flatMap { $0.label(forMonth: month) },
                      weekdayHeaders: headers,
                      weeks: weeks,
                      weekNumbers: weekNumbers,
                      showsOutsideDays: options.showOutsideDays)
}

func applyFirstWeekday(_ override: Int?, to calendar: inout Calendar) {
    if let override {
        calendar.firstWeekday = override
        calendar.minimumDaysInFirstWeek = override == 2 ? 4 : 1
    } else if calendar.firstWeekday == 2 {
        calendar.minimumDaysInFirstWeek = 4
    }
}

/// Timeline entry dates: now plus the next two midnights. Midnights come
/// from `Calendar`, so DST transitions stay aligned.
public func timelineDates(from now: Date, calendar: Calendar) -> [Date] {
    let todayStart = calendar.startOfDay(for: now)
    let midnights = (1...2).compactMap { calendar.date(byAdding: .day, value: $0, to: todayStart) }

    return [now] + midnights
}

enum Civil {
    static func isLeap(_ year: Int) -> Bool {
        year % 4 == 0 && (year % 100 != 0 || year % 400 == 0)
    }

    static func daysInMonth(_ year: Int, _ month: Int) -> Int {
        switch month {
        case 2: isLeap(year) ? 29 : 28
        case 4, 6, 9, 11: 30
        default: 31
        }
    }

    static func daysInYear(_ year: Int) -> Int { isLeap(year) ? 366 : 365 }

    /// Cumulative days before each month in a common year; index 1 = January.
    private static let daysBeforeMonth = [0, 0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334]

    static func dayOfYear(_ year: Int, _ month: Int, _ day: Int) -> Int {
        daysBeforeMonth[month] + day + ((month > 2 && isLeap(year)) ? 1 : 0)
    }

    /// Days since 1970-01-01 (Howard Hinnant's `days_from_civil`).
    static func daysSinceEpoch(_ year: Int, _ month: Int, _ day: Int) -> Int {
        // January and February (`<= 2`) are treated as part of the previous
        // March-based year (`- 1`).
        let shifted = month <= 2 ? year - 1 : year

        // Gregorian leap rules repeat every 400 years; subtracting 399 before
        // `/ 400` keeps negative years floored into the right era.
        let era = (shifted >= 0 ? shifted : shifted - 399) / 400

        // Year number inside the current 400-year era.
        let yearOfEra = shifted - era * 400

        // Reindex months so March starts at 0 (`- 3`) and Jan/Feb become
        // 10 and 11 (`+ 9`); `153`, `+ 2`, and `/ 5` are the integer month
        // length transform, and `- 1` makes the day count zero-based.
        let dayOfMarchYear = (153 * (month > 2 ? month - 3 : month + 9) + 2) / 5 + day - 1

        // Count common-year days (`365`), add leap days every 4 years, and
        // remove the skipped century leap days every 100 years.
        let dayOfEra = yearOfEra * 365 + yearOfEra / 4 - yearOfEra / 100 + dayOfMarchYear

        // Each 400-year era has 146_097 days; 719_468 shifts that March-based
        // origin to the Unix epoch.
        return era * 146_097 + dayOfEra - 719_468
    }

    /// `Calendar`-convention weekday: 1 = Sunday … 7 = Saturday.
    static func weekday(_ year: Int, _ month: Int, _ day: Int) -> Int {
        // 1970-01-01 was a Thursday — index 4 counting Sunday as 0.
        positiveMod(daysSinceEpoch(year, month, day) + 4, 7) + 1
    }

    /// Week of year under `Calendar`'s rule: weeks start on `firstWeekday`,
    /// and week 1 is the first week holding at least `minimumDays` days of
    /// the year. `firstWeekday` 2 with `minimumDays` 4 is ISO 8601.
    static func weekOfYear(_ year: Int, _ month: Int, _ day: Int,
                           firstWeekday: Int, minimumDays: Int) -> Int {
        let dayNumber = dayOfYear(year, month, day)
        let positionInWeek = positiveMod(weekday(year, month, day) - firstWeekday, 7)

        // A December week reaching at least `minimumDays` into January
        // already belongs to next year as its week 1.
        let weekStart = dayNumber - positionInWeek
        if weekStart + 6 - daysInYear(year) >= minimumDays { return 1 }

        // Count week rows from the week containing Jan 1; that row is week 1
        // only when it keeps at least `minimumDays` days in this year.
        let jan1Position = positiveMod(weekday(year, 1, 1) - firstWeekday, 7)
        let row = (dayNumber - 1 + jan1Position) / 7
        let week = row + (7 - jan1Position >= minimumDays ? 1 : 0)
        if week > 0 { return week }

        // Week 0 means the date's week is the previous year's last week.
        // Dec 31 shares that week, so the recursion terminates in one step.
        return weekOfYear(year - 1, 12, 31,
                          firstWeekday: firstWeekday, minimumDays: minimumDays)
    }

    static func positiveMod(_ value: Int, _ modulus: Int) -> Int {
        let remainder = value % modulus
        return remainder >= 0 ? remainder : remainder + modulus
    }
}
