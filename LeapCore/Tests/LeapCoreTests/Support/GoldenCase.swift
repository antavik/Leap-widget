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
                    offsets: [Int],
                    showYear: Bool,
                    options: MonthOptions)
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

    // Named for what it is: `en_US` is Sunday-first with a one-day rule, and
    // this overrides both.
    private static let isoMondayFirst = Fixtures.calendar(locale: "en_US", firstWeekday: 2,
                                                          minimumDaysInFirstWeek: 4)
    private static let sundayFirst = Fixtures.sundayFirst
    private static let deDE = Fixtures.germanMondayFirst
    // Named here for its symbols; `Fixtures` names it for its weekend.
    private static let arSA = Fixtures.fridaySaturdayWeekend

    private static func widget(_ tile: WidgetGeometry,
                               calendar: Calendar = isoMondayFirst,
                               reference: DateComponents = referenceDay,
                               offsets: [Int] = [0],
                               showYear: Bool = true,
                               options: MonthOptions = MonthOptions()) -> Content {
        .widget(tile: tile, calendar: calendar, reference: reference,
                offsets: offsets, showYear: showYear, options: options)
    }

    /// Every option that can move a pixel, at the two shipping families.
    static let widgetCases: [GoldenCase] = [
        GoldenCase("01-small-default-light", widget(.small)),
        GoldenCase("02-small-default-dark", widget(.small), scheme: .dark),
        GoldenCase("03-small-week-numbers",
                   widget(.small, options: MonthOptions(showWeekNumbers: true))),
        GoldenCase("04-small-outside-days-hidden",
                   widget(.small, options: MonthOptions(showOutsideDays: false))),
        GoldenCase("05-small-month-number-arabic",
                   widget(.small, options: MonthOptions(monthNumberStyle: .arabic))),
        GoldenCase("06-small-month-number-roman",
                   widget(.small, options: MonthOptions(monthNumberStyle: .roman))),
        GoldenCase("07-small-roman-week-numbers",
                   widget(.small, options: MonthOptions(showWeekNumbers: true,
                                                        monthNumberStyle: .roman))),
        GoldenCase("08-small-year-label-off", widget(.small, showYear: false)),
        GoldenCase("09-small-sunday-first", widget(.small, calendar: sundayFirst)),
        GoldenCase("10-small-february-two-blank-rows",
                   widget(.small, calendar: sundayFirst,
                          reference: DateComponents(year: 2026, month: 2, day: 10, hour: 12),
                          options: MonthOptions(showOutsideDays: false))),
        GoldenCase("11-small-december-from-january",
                   widget(.small,
                          reference: DateComponents(year: 2027, month: 1, day: 10, hour: 12),
                          offsets: [-1])),
        // The measured tightest shipping case: 143×164 pt inside a 170×170 tile.
        GoldenCase("12-small-de-december-roman-week-numbers",
                   widget(.small, calendar: deDE, reference: december,
                          options: MonthOptions(showWeekNumbers: true,
                                                monthNumberStyle: .roman))),
        // Locale is a model input, not an environment value: the Arabic symbols
        // only appear because the *calendar* is ar_SA.
        GoldenCase("13-small-arabic-calendar-ltr", widget(.small, calendar: arSA)),
        GoldenCase("14-small-right-to-left", widget(.small),
                   layoutDirection: .rightToLeft),
        GoldenCase("15-medium-default-light", widget(.medium, offsets: [0, 1])),
        GoldenCase("16-medium-default-dark", widget(.medium, offsets: [0, 1]),
                   scheme: .dark),
        GoldenCase("17-medium-previous-companion", widget(.medium, offsets: [-1, 0])),
        GoldenCase("18-medium-week-numbers",
                   widget(.medium, offsets: [0, 1],
                          options: MonthOptions(showWeekNumbers: true))),
        GoldenCase("19-medium-december-week-numbers",
                   widget(.medium, reference: december, offsets: [0, 1],
                          options: MonthOptions(showWeekNumbers: true))),
        GoldenCase("20-medium-roman-week-numbers",
                   widget(.medium, offsets: [0, 1],
                          options: MonthOptions(showWeekNumbers: true,
                                                monthNumberStyle: .roman))),
        // The year label overlays the *row*, not one month, so the two-month
        // tile is its own case; 08 covers only the single-month overlay.
        GoldenCase("24-medium-year-label-off",
                   widget(.medium, offsets: [0, 1], showYear: false)),
    ]

    /// The app's only real UI surface.
    ///
    /// Measured limit: `ImageRenderer` cannot draw interactive views, so the
    /// donation row's two `Link`s record as SwiftUI's placeholder. Geometry is
    /// still pinned; their text and colour stay a release-checklist item.
    ///
    /// No `de_DE` case: both catalogues ship `en` only, so the recorded
    /// `23-onboarding-de.png` was byte-identical to 21 and could only fail when
    /// 21 already had. The wrapping it was meant to cover is asserted by
    /// `LayoutInvariantTests.longerStepTextGrowsTheStepInsteadOfClipping`.
    static let onboardingCases: [GoldenCase] = [
        GoldenCase("21-onboarding-light", .onboarding(locale: Locale(identifier: "en_US"))),
        GoldenCase("22-onboarding-dark", .onboarding(locale: Locale(identifier: "en_US")),
                   scheme: .dark),
    ]

    static var all: [GoldenCase] { widgetCases + onboardingCases }
}

// MARK: - Rendering a case

extension GoldenCase {
    @MainActor
    func render() throws -> CGImage {
        switch content {
        case let .widget(tile, calendar, reference, offsets, showYear, options):
            let date = try #require(calendar.date(from: reference),
                                    "no reference date for \(id)")
            let row = monthRow(containing: date,
                               offsets: offsets,
                               showYear: showYear,
                               builder: MonthModelBuilder(calendar: calendar,
                                                          options: options))
            let surface = CalendarSurface(models: row.models,
                                          yearLabel: row.yearLabel)

            return try #require(RenderHarness.render(surface,
                                                     size: tile.tile,
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

    /// Without the tile frame or the content padding — what the clipping
    /// invariant compares against `WidgetGeometry.contentBox`.
    @MainActor
    func intrinsicContentSize() throws -> CGSize {
        switch content {
        case let .widget(_, calendar, reference, offsets, showYear, options):
            let date = try #require(calendar.date(from: reference))
            let row = monthRow(containing: date, offsets: offsets, showYear: showYear,
                               builder: MonthModelBuilder(calendar: calendar,
                                                          options: options))

            return try #require(RenderHarness.intrinsicSize(
                MultiMonthView(models: row.models, yearLabel: row.yearLabel),
                scheme: scheme))

        case let .onboarding(locale):
            return try #require(RenderHarness.intrinsicSize(
                OnboardingView().environment(\.locale, locale),
                scheme: scheme))
        }
    }

    var tile: WidgetGeometry? {
        switch content {
        case let .widget(tile, _, _, _, _, _): tile
        case .onboarding: nil
        }
    }
}
