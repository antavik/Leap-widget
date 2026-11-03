import Foundation

public struct MonthModelBuilder: Sendable {
    private let calendar: Calendar
    private let options: MonthOptions
    private let firstWeekday: Int
    private let monthTitles: [String]
    private let weekdayHeaders: [String]
    private let weekendColumns: [Bool]
    private let monthYearStyle: Date.FormatStyle
    private let todayStyle: Date.FormatStyle

    /// Whether this calendar can use a two-digit Gregorian year label.
    public let usesGregorianYearNumbering: Bool

    /// Stands in when a calendar reports no length for a month.
    ///
    /// Unreachable for the calendars in use; it only keeps the grid drawable
    /// instead of trapping.
    private static let fallbackDayCount = 30

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

        let baseStyle = Date.FormatStyle(date: .omitted, time: .omitted,
                                         locale: locale ?? .autoupdatingCurrent,
                                         calendar: effective,
                                         timeZone: effective.timeZone)
        self.monthYearStyle = baseStyle.year().month(.wide)
        self.todayStyle = baseStyle.year().month(.wide).day().weekday(.wide)

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
        self.weekendColumns = (0..<7).map { weekend[(firstIndex + $0) % 7] }
    }

    /// Builds the display model for the month `offset` months from `date`.
    ///
    /// - Parameters:
    ///   - date: any date in the reference month.
    ///   - offset: months relative to the reference month (-1, 0, +1).
    ///   - today: marks its day only in the offset-0 month.
    /// - Returns: a grid that always has a full set of cells. A calendar that
    ///   reports no month length or cannot shift a date degrades the affected
    ///   day numbers to a 30-day approximation rather than failing; the
    ///   supported calendars never take that path.
    public func model(containing date: Date, offset: Int, today: Date) -> MonthModel {
        let shifted = calendar.date(byAdding: .month, value: offset, to: date) ?? date
        let components = calendar.dateComponents([.year, .month], from: shifted)
        let monthStart = calendar.date(from: components) ?? calendar.startOfDay(for: shifted)
        let year = components.year ?? calendar.component(.year, from: shifted)
        let month = components.month ?? calendar.component(.month, from: shifted)
        let dayCount = calendar.range(of: .day, in: .month, for: monthStart)?.count
            ?? Self.fallbackDayCount

        let leadingCount = (calendar.component(.weekday, from: monthStart)
                            - firstWeekday + 7) % 7

        // Leading cells show the previous month's tail; its length is all the
        // date math those cells need.
        let previousMonthStart = calendar.date(byAdding: .month, value: -1, to: monthStart)
        let previousDayCount = previousMonthStart
            .flatMap { calendar.range(of: .day, in: .month, for: $0)?.count }
            ?? Self.fallbackDayCount

        // The today marker reduces to one day-number comparison: it can only
        // sit in the offset-0 month, and only when `today` falls inside it.
        let todayComponents = calendar.dateComponents([.year, .month, .day], from: today)
        let todayNumber: Int? = (offset == 0 && todayComponents.year == year
                                 && todayComponents.month == month)
            ? todayComponents.day : nil

        // Always six full rows: leading/trailing cells carry adjacent-month
        // days so 5- and 6-week months keep identical geometry. Day numbers
        // derive from the two month lengths – no per-cell `Date`.
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
                                isOutsideMonth: outside))
            }
            weeks.append(days)

            if options.showWeekNumbers {
                // A row is one calendar week, so its first day yields the number.
                let rowFirstDate = calendar.date(byAdding: .day,
                                                 value: row * 7 - leadingCount,
                                                 to: monthStart) ?? monthStart
                weekNumbers?.append(calendar.component(.weekOfYear, from: rowFirstDate))
            }
        }

        return MonthModel(title: title(forMonth: month),
                          year: year,
                          monthNumberLabel: options.monthNumberStyle
                              .flatMap { $0.label(forMonth: month) },
                          weekdayHeaders: weekdayHeaders,
                          weekendColumns: weekendColumns,
                          weeks: weeks,
                          weekNumbers: weekNumbers,
                          showsOutsideDays: options.showOutsideDays,
                          containsToday: todayNumber != nil,
                          spokenSummary: spokenSummary(monthStart: monthStart,
                                                       today: today,
                                                       holdsToday: todayNumber != nil))
    }
}

private extension MonthModelBuilder {
    func title(forMonth month: Int) -> String {
        monthTitles.indices.contains(month - 1) ? monthTitles[month - 1] : String(month)
    }

    func spokenSummary(monthStart: Date, today: Date, holdsToday: Bool) -> String {
        guard holdsToday else { return monthStart.formatted(monthYearStyle) }

        let date = today.formatted(todayStyle)

        guard options.showWeekNumbers else {
            return String(localized: "Today is \(date)", bundle: .module,
                          comment: "VoiceOver label for the month holding today")
        }

        let week = calendar.component(.weekOfYear, from: today)

        return String(localized: "Today is \(date), week \(week)", bundle: .module,
                      comment: "VoiceOver label for the month holding today, week numbers on")
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
/// - Returns: a grid that always has a full set of cells; see
///   `MonthModelBuilder.model(containing:offset:today:)` for how a calendar
///   that reports nothing is approximated.
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
