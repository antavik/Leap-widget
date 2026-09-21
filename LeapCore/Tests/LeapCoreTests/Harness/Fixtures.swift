import Testing
import Foundation
@testable import LeapCore

enum Fixtures {
    /// Monday-first, ISO week rules (UK-style region).
    static let mondayFirst = calendar(locale: "en_GB", firstWeekday: 2,
                                      minimumDaysInFirstWeek: 4)
    /// Sunday-first, US week rules.
    static let sundayFirst = calendar(locale: "en_US", firstWeekday: 1,
                                      minimumDaysInFirstWeek: 1)
    /// Friday–Saturday weekend region.
    static let fridaySaturdayWeekend = calendar(locale: "ar_SA", firstWeekday: 1,
                                                minimumDaysInFirstWeek: 1)
    /// German: Monday-first ISO rules, and the locale where text wraps first.
    static let germanMondayFirst = calendar(locale: "de_DE", firstWeekday: 2,
                                            minimumDaysInFirstWeek: 4)

    static func calendar(identifier: Calendar.Identifier = .gregorian,
                         locale: String,
                         firstWeekday: Int? = nil,
                         minimumDaysInFirstWeek: Int? = nil,
                         timeZone: String = "GMT") -> Calendar {
        var calendar = Calendar(identifier: identifier)
        calendar.locale = Locale(identifier: locale)
        if let firstWeekday { calendar.firstWeekday = firstWeekday }
        if let minimumDaysInFirstWeek {
            calendar.minimumDaysInFirstWeek = minimumDaysInFirstWeek
        }
        calendar.timeZone = TimeZone(identifier: timeZone) ?? .gmt

        return calendar
    }

    static func date(_ year: Int, _ month: Int, _ day: Int,
                     hour: Int = 12,
                     in calendar: Calendar,
                     sourceLocation: SourceLocation = #_sourceLocation) throws -> Date {
        try #require(calendar.date(from: DateComponents(year: year, month: month,
                                                        day: day, hour: hour)),
                     "no date for \(year)-\(month)-\(day) in \(calendar.identifier)",
                     sourceLocation: sourceLocation)
    }

    static let referenceDay = DateComponents(year: 2026, month: 8, day: 12, hour: 12)
    static let december = DateComponents(year: 2026, month: 12, day: 15, hour: 12)
}
