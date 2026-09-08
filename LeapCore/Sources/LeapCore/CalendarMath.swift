import Foundation

/// Builds month models for a widget reload, resolving the calendar's month
/// names, weekday headers, and weekend map once so the months of one reload
/// share them.
public struct MonthModelBuilder: Sendable {
    private let calendar: Calendar
    private let options: MonthOptions
    private let firstWeekday: Int
    private let monthTitles: [String]
    private let weekdayHeaders: [String]
    private let weekendByWeekday: [Bool]

    /// Whether the calendar numbers years the Gregorian way, so the two-digit
    /// apostrophe form reads correctly. Era calendars (Japanese, Republic of
    /// China) and other epochs (Buddhist, Hebrew) print their year in full:
    /// Reiwa 8 as \u{2019}08 would read as 2008.
    public let usesGregorianYearNumbering: Bool

    public init(calendar: Calendar, options: MonthOptions) {
        var effective = calendar
        applyFirstWeekday(options.firstWeekday, to: &effective)
        self.calendar = effective

        self.options = options
        self.firstWeekday = effective.firstWeekday
        self.usesGregorianYearNumbering = effective.identifier == .gregorian
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
        let shifted = calendar.date(byAdding: .month, value: offset, to: date)!
        let components = calendar.dateComponents([.year, .month], from: shifted)
        let monthStart = calendar.date(from: components)!
        let year = components.year!
        let month = components.month!
        let dayCount = calendar.range(of: .day, in: .month, for: monthStart)!.count

        let leadingCount = (calendar.component(.weekday, from: monthStart)
                            - firstWeekday + 7) % 7

        // Leading cells show the previous month's tail; its length is all the
        // date math those cells need.
        let previousMonthStart = calendar.date(byAdding: .month, value: -1, to: monthStart)!
        let previousDayCount = calendar.range(of: .day, in: .month,
                                              for: previousMonthStart)!.count

        // The today marker reduces to one day-number comparison: it can only
        // sit in the offset-0 month, and only when `today` falls inside it.
        let todayComponents = calendar.dateComponents([.year, .month, .day], from: today)
        let todayNumber: Int? = (offset == 0 && todayComponents.year == year
                                 && todayComponents.month == month)
            ? todayComponents.day : nil

        // Always six full rows: leading/trailing cells carry adjacent-month
        // days so 5- and 6-week months keep identical geometry. Day numbers
        // derive from the two month lengths — no per-cell `Date`.
        var weeks: [[Day]] = []
        weeks.reserveCapacity(6)
        var weekNumbers: [Int]? = options.showWeekNumbers ? [] : nil
        for row in 0..<6 {
            var days: [Day] = []
            days.reserveCapacity(7)
            for column in 0..<7 {
                let dayOffset = row * 7 + column - leadingCount
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
                // A row is one calendar week, so its first day yields the number.
                let rowFirstDate = calendar.date(byAdding: .day,
                                                 value: row * 7 - leadingCount,
                                                 to: monthStart)!
                weekNumbers?.append(calendar.component(.weekOfYear, from: rowFirstDate))
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
