import Testing
import Foundation
@testable import LeapCore

/// The arithmetic fast path must be indistinguishable from the Calendar/ICU
/// path. These sweeps are the safety net that lets production skip ICU.
private func parityCalendar(identifier: Calendar.Identifier = .gregorian,
                            locale: String, timeZone: String = "GMT") -> Calendar {
    var calendar = Calendar(identifier: identifier)
    calendar.locale = Locale(identifier: locale)
    calendar.timeZone = TimeZone(identifier: timeZone)!
    return calendar
}

/// Monthly coverage around the present plus boundary days sampled across two
/// centuries: leap Februaries, Dec/Jan wraps, DST-transition months.
private func parityProbes(in calendar: Calendar) -> [Date] {
    var probes: [Date] = []
    let base = calendar.date(from: DateComponents(year: 2024, month: 1, day: 15))!
    for monthIndex in 0..<36 {
        probes.append(calendar.date(byAdding: .month, value: monthIndex, to: base)!)
    }
    for year in stride(from: 1900, through: 2100, by: 20) {
        for (month, day) in [(1, 1), (2, 28), (3, 9), (11, 2), (12, 31)] {
            probes.append(calendar.date(from: DateComponents(
                year: year, month: month, day: day, hour: 12))!)
        }
    }
    return probes
}

/// Reports the first mismatching model pair, if any, so a sweep failure names
/// the exact configuration instead of drowning the log in expectations.
private func firstMismatch(calendar: Calendar, options: MonthOptions,
                           probes: [Date]) -> String? {
    let builder = MonthModelBuilder(calendar: calendar, options: options)
    for probe in probes {
        for offset in -1...1 {
            let fast = builder.model(containing: probe, offset: offset, today: probe)
            let oracle = monthModelUsingCalendar(containing: probe, offset: offset,
                                                 calendar: calendar, today: probe,
                                                 options: options)
            if fast != oracle {
                return "date=\(probe) offset=\(offset)"
            }
        }
    }
    return nil
}

/// Every day 2020–2035 under every first weekday and both minimum-days
/// conventions (US-style 1, ISO-style 4): ~82k comparisons against
/// `Calendar.component(.weekOfYear)`.
@Test func civilWeekOfYearMatchesCalendarForEveryRule() {
    for firstWeekday in 1...7 {
        for minimumDays in [1, 4] {
            var calendar = parityCalendar(locale: "en_US")
            calendar.firstWeekday = firstWeekday
            calendar.minimumDaysInFirstWeek = minimumDays

            var time = calendar.date(from: DateComponents(year: 2020, month: 1, day: 1))!
                .timeIntervalSince1970
            var (year, month, day) = (2020, 1, 1)
            while year < 2036 {
                let expected = calendar.component(.weekOfYear,
                                                  from: Date(timeIntervalSince1970: time))
                let got = Civil.weekOfYear(year, month, day,
                                           firstWeekday: firstWeekday,
                                           minimumDays: minimumDays)
                if got != expected {
                    Issue.record("\(year)-\(month)-\(day) firstWeekday=\(firstWeekday) minimumDays=\(minimumDays): calendar \(expected), civil \(got)")
                    return
                }
                time += 86_400          // GMT days are uniform
                day += 1
                if day > Civil.daysInMonth(year, month) { day = 1; month += 1 }
                if month > 12 { month = 1; year += 1 }
            }
        }
    }
}

/// Full-model sweep: locales with different weekend/first-day conventions,
/// time zones including a non-hour offset, every first-weekday override.
@Test func fastPathMatchesCalendarPathAcrossLocalesAndCenturies() {
    for localeID in ["en_US", "de_DE", "ar_SA", "he_IL"] {
        for timeZoneID in ["GMT", "America/New_York", "Asia/Kathmandu"] {
            let calendar = parityCalendar(locale: localeID, timeZone: timeZoneID)
            let probes = parityProbes(in: calendar)
            // Week numbers on: the off model is a subset. Month-number labels
            // come from the same table on both paths, so no style dimension.
            for firstWeekday in [nil, 1, 2, 7] as [Int?] {
                let options = MonthOptions(firstWeekday: firstWeekday, showWeekNumbers: true)
                if let mismatch = firstMismatch(calendar: calendar,
                                                options: options, probes: probes) {
                    Issue.record("locale=\(localeID) timeZone=\(timeZoneID) firstWeekday=\(String(describing: firstWeekday)) \(mismatch)")
                    return
                }
            }
        }
    }
}

/// `.iso8601` shares the fast path; its default Monday-first/4-day rule must
/// survive the builder's snapshot.
@Test func iso8601IdentifierMatchesCalendarPath() {
    let calendar = parityCalendar(identifier: .iso8601, locale: "en_GB")
    let options = MonthOptions(showWeekNumbers: true)
    let mismatch = firstMismatch(calendar: calendar, options: options,
                                 probes: parityProbes(in: calendar))
    #expect(mismatch == nil, Comment(rawValue: mismatch ?? ""))
}

/// Non-Gregorian identifiers must route to the Calendar path — this fails if
/// one is ever added to the fast path without its own arithmetic.
@Test func nonGregorianCalendarsFallBackToCalendarPath() {
    // Buddhist shifts year numbering; Hebrew leap years add month 13.
    // Roman labels stay on so both paths agree there too.
    for identifier in [Calendar.Identifier.hebrew, .islamicUmmAlQura, .buddhist] {
        let calendar = parityCalendar(identifier: identifier, locale: "en_US")
        let options = MonthOptions(showWeekNumbers: true, monthNumberStyle: .roman)
        let builder = MonthModelBuilder(calendar: calendar, options: options)
        let reference = Date(timeIntervalSince1970: 1_787_000_000)  // Aug 2026
        for offset in -1...1 {
            let viaBuilder = builder.model(containing: reference, offset: offset,
                                           today: reference)
            let viaCalendar = monthModelUsingCalendar(containing: reference,
                                                      offset: offset,
                                                      calendar: calendar,
                                                      today: reference,
                                                      options: options)
            #expect(viaBuilder == viaCalendar, "identifier=\(identifier) offset=\(offset)")
        }
    }
}
