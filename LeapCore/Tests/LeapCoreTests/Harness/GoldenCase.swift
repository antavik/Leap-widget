import Testing
import SwiftUI
import Foundation
@testable import LeapCore

/// Everything needed to rebuild exactly one render. A spanning set, not a
/// cross product.
struct GoldenCase: Sendable, CustomTestStringConvertible {
    enum Content: Sendable {
        case widget(tile: WidgetGeometry,
                    calendar: Calendar,
                    reference: DateComponents,
                    settings: CalendarSettings)
        case onboarding(locale: Locale)
    }

    let id: String
    let content: Content
    let scheme: ColorScheme
    let layoutDirection: LayoutDirection

    var testDescription: String { id }

    init(_ id: String,
         _ content: Content,
         scheme: ColorScheme = .light,
         layoutDirection: LayoutDirection = .leftToRight) {
        self.id = id
        self.content = content
        self.scheme = scheme
        self.layoutDirection = layoutDirection
    }
}

// MARK: - The matrix

extension GoldenCase {
    static let referenceDay = Fixtures.referenceDay
    static let december = Fixtures.december
    static let january = DateComponents(year: 2027, month: 1, day: 10, hour: 12)
    static let february = DateComponents(year: 2026, month: 2, day: 10, hour: 12)

    // Named for what it is: `en_US` is Sunday-first with a one-day rule, and
    // this overrides both.
    private static let isoMondayFirst = Fixtures.calendar(locale: "en_US", firstWeekday: 2,
                                                          minimumDaysInFirstWeek: 4)
    private static let sundayFirst = Fixtures.sundayFirst
    private static let deDE = Fixtures.germanMondayFirst
    // Named here for its symbols; `Fixtures` names it for its weekend.
    private static let arSA = Fixtures.fridaySaturdayWeekend

    /// The single-month widget, configured through its own options.
    private static func small(_ month: DisplayedMonth = .current,
                              calendar: Calendar = isoMondayFirst,
                              reference: DateComponents = referenceDay,
                              firstWeekday: FirstWeekday = .system,
                              showWeekNumbers: Bool = false,
                              showOutsideDays: Bool = true,
                              showYear: Bool = true,
                              monthNumber: MonthNumberDisplay = .off) -> Content {
        .widget(tile: .small, calendar: calendar, reference: reference,
                settings: CalendarSettings(monthOffsets: month.monthOffsets,
                                           firstWeekday: firstWeekday,
                                           showWeekNumbers: showWeekNumbers,
                                           showOutsideDays: showOutsideDays,
                                           showYear: showYear,
                                           monthNumber: monthNumber))
    }

    /// The two-month widget, configured through its own options.
    private static func medium(_ companion: Companion = .next,
                               calendar: Calendar = isoMondayFirst,
                               reference: DateComponents = referenceDay,
                               firstWeekday: FirstWeekday = .system,
                               showWeekNumbers: Bool = false,
                               showOutsideDays: Bool = true,
                               showYear: Bool = true,
                               monthNumber: MonthNumberDisplay = .off) -> Content {
        .widget(tile: .medium, calendar: calendar, reference: reference,
                settings: CalendarSettings(monthOffsets: companion.monthOffsets,
                                           firstWeekday: firstWeekday,
                                           showWeekNumbers: showWeekNumbers,
                                           showOutsideDays: showOutsideDays,
                                           showYear: showYear,
                                           monthNumber: monthNumber))
    }

    /// Every option that can move a pixel, at the two shipping families.
    static let widgetCases: [GoldenCase] = [
        GoldenCase("01-small-default-light", small()),
        GoldenCase("02-small-default-dark", small(), scheme: .dark),
        GoldenCase("03-small-week-numbers", small(showWeekNumbers: true)),
        GoldenCase("04-small-outside-days-hidden", small(showOutsideDays: false)),
        GoldenCase("05-small-week-numbers-outside-days-hidden",
                   small(calendar: sundayFirst, reference: february,
                         showWeekNumbers: true, showOutsideDays: false)),
        GoldenCase("06-small-month-number-arabic", small(monthNumber: .arabic)),
        GoldenCase("07-small-month-number-roman", small(monthNumber: .roman)),
        GoldenCase("08-small-roman-week-numbers",
                   small(showWeekNumbers: true, monthNumber: .roman)),
        GoldenCase("09-small-year-label-off", small(showYear: false)),
        GoldenCase("10-small-sunday-first", small(calendar: sundayFirst)),
        GoldenCase("11-small-february-two-blank-rows",
                   small(calendar: sundayFirst, reference: february,
                         showOutsideDays: false)),
        GoldenCase("12-small-december-from-january", small(.previous, reference: january)),
        GoldenCase("13-small-de-december-roman-week-numbers",
                   small(calendar: deDE, reference: december,
                         showWeekNumbers: true, monthNumber: .roman)),
        GoldenCase("14-small-arabic-calendar-ltr", small(calendar: arSA)),
        GoldenCase("15-small-right-to-left", small(), layoutDirection: .rightToLeft),
        GoldenCase("16-medium-default-light", medium()),
        GoldenCase("17-medium-default-dark", medium(), scheme: .dark),
        GoldenCase("18-medium-previous-companion", medium(.previous)),
        GoldenCase("19-medium-week-numbers", medium(showWeekNumbers: true)),
        GoldenCase("20-medium-december-week-numbers",
                   medium(reference: december, showWeekNumbers: true)),
        GoldenCase("21-medium-roman-week-numbers",
                   medium(showWeekNumbers: true, monthNumber: .roman)),
        GoldenCase("22-medium-year-label-off", medium(showYear: false)),
        GoldenCase("25-small-next-month", small(.next)),
        GoldenCase("26-small-january-from-december", small(.next, reference: december)),
        GoldenCase("27-medium-previous-companion-january", medium(.previous, reference: january)),
        GoldenCase("28-medium-dark-all-options",
                   medium(firstWeekday: .sunday, showWeekNumbers: true,
                          showOutsideDays: false, monthNumber: .roman),
                   scheme: .dark),
        GoldenCase("29-small-year-off-outside-days-hidden",
                   small(showOutsideDays: false, showYear: false)),
        GoldenCase("30-medium-outside-days-hidden", medium(showOutsideDays: false)),
        GoldenCase("31-medium-month-number-arabic", medium(monthNumber: .arabic)),
        GoldenCase("32-medium-sunday-first", medium(firstWeekday: .sunday)),
        GoldenCase("33-medium-december-dark", medium(reference: december), scheme: .dark),
        GoldenCase("34-medium-previous-companion-january-dark",
                   medium(.previous, reference: january), scheme: .dark),
    ]

    static let onboardingCases: [GoldenCase] = [
        GoldenCase("23-onboarding-light", .onboarding(locale: Locale(identifier: "en_US"))),
        GoldenCase("24-onboarding-dark", .onboarding(locale: Locale(identifier: "en_US")),
                   scheme: .dark),
    ]

    static var all: [GoldenCase] { widgetCases + onboardingCases }
}

// MARK: - Rendering a case

extension GoldenCase {
    /// The entry the widget's provider would serve first for these settings.
    static func entry(settings: CalendarSettings,
                      calendar: Calendar,
                      reference: DateComponents,
                      sourceLocation: SourceLocation = #_sourceLocation)
    throws -> CalendarEntryModel {
        let now = try #require(calendar.date(from: reference),
                               "no reference date", sourceLocation: sourceLocation)

        return try #require(calendarEntries(for: settings, now: now, calendar: calendar).first,
                            "no timeline entry", sourceLocation: sourceLocation)
    }

    @MainActor
    func render() throws -> CGImage {
        switch content {
        case let .widget(tile, calendar, reference, settings):
            let entry = try Self.entry(settings: settings, calendar: calendar,
                                       reference: reference)
            let surface = CalendarSurface(models: entry.models,
                                          yearLabels: entry.yearLabels)

            return try #require(RenderHarness.render(surface,
                                                     size: tile.tileSize,
                                                     scheme: scheme,
                                                     layoutDirection: layoutDirection),
                                "render produced no image for \(id)")

        case let .onboarding(locale):
            return try #require(
                RenderHarness.renderFlexibleHeight(
                    OnboardingView().environment(\.locale, locale),
                    width: OnboardingView.width,
                    scheme: scheme,
                    layoutDirection: layoutDirection),
                "render produced no image for \(id)")
        }
    }

    /// Without the tile frame or the content padding – what the clipping
    /// invariant compares against `WidgetGeometry.contentBox`.
    @MainActor
    func intrinsicContentSize() throws -> CGSize {
        switch content {
        case let .widget(_, calendar, reference, settings):
            let entry = try Self.entry(settings: settings, calendar: calendar,
                                       reference: reference)

            return try #require(RenderHarness.intrinsicSize(
                MultiMonthView(models: entry.models, yearLabels: entry.yearLabels),
                scheme: scheme,
                layoutDirection: layoutDirection))

        case let .onboarding(locale):
            return try #require(RenderHarness.intrinsicSize(
                OnboardingView().environment(\.locale, locale),
                scheme: scheme,
                layoutDirection: layoutDirection))
        }
    }

    var tile: WidgetGeometry? {
        switch content {
        case let .widget(tile, _, _, _): tile
        case .onboarding: nil
        }
    }
}
