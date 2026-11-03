import Testing
import SwiftUI
import Foundation
import LeapCore

/// The shipping view, built from the real intents. `RenderHarness` stands in
/// for `containerBackground`, as for the goldens.
@Suite("Widget view", .serialized, .warmRenderer)
@MainActor
struct WidgetViewRenderTests {
    private typealias Buffer = ImageComparator.Buffer

    private static let calendar = Fixtures.mondayFirst

    private func render(_ view: some View, geometry: WidgetGeometry) throws -> Buffer {
        let image = try #require(RenderHarness.render(view, size: geometry.tileSize,
                                                      scheme: .light,
                                                      layoutDirection: .leftToRight))
        return try #require(ImageComparator.buffer(of: image))
    }

    private func entry(_ config: some CalendarConfiguration) throws -> CalendarEntry {
        let date = try Fixtures.date(2026, 8, 12, in: Self.calendar)
        return CalendarEntry(date: date, config: config, calendar: Self.calendar)
    }

    private func twoMonthWidget(_ edit: (CalendarConfigIntent) -> Void = { _ in }) throws -> Buffer {
        let intent = CalendarConfigIntent()
        edit(intent)
        return try render(CalendarWidgetView(entry: entry(intent)), geometry: .medium)
    }

    private func oneMonthWidget(
        _ edit: (SmallCalendarConfigIntent) -> Void = { _ in }
    ) throws -> Buffer {
        let intent = SmallCalendarConfigIntent()
        edit(intent)
        return try render(CalendarWidgetView(entry: entry(intent)), geometry: .small)
    }

    // MARK: - The widget view draws what the goldens pin

    /// Ties the goldens, which render `CalendarSurface`, to the shipping view.
    @Test func theWidgetViewDrawsExactlyTheSurface() throws {
        let medium = try entry(CalendarConfigIntent())
        let small = try entry(SmallCalendarConfigIntent())

        for (placed, geometry) in [(medium, WidgetGeometry.medium), (small, .small)] {
            let widget = try render(CalendarWidgetView(entry: placed), geometry: geometry)
            let surface = try render(CalendarSurface(models: placed.model.models,
                                                     yearLabel: placed.model.yearLabel),
                                     geometry: geometry)
            let diff = ImageComparator.compare(expected: surface, actual: widget)

            #expect(!ImageComparator.isFlat(widget), "\(geometry): the widget drew nothing")
            #expect(diff.differingPixels == 0, "\(geometry): \(diff.summary)")
        }
    }

    // MARK: - Click action

    /// `widgetURL`, or an inert `Button` for "Nothing" – neither may show.
    @Test func theClickActionNeverChangesThePixels() throws {
        let medium = try twoMonthWidget { $0.clickAction = ClickAction.appleCalendar.rawValue }
        let small = try oneMonthWidget { $0.clickAction = ClickAction.appleCalendar.rawValue }

        for action in ClickAction.allCases {
            let twoMonthDiff = ImageComparator.compare(
                expected: medium, actual: try twoMonthWidget { $0.clickAction = action.rawValue })
            let oneMonthDiff = ImageComparator.compare(
                expected: small, actual: try oneMonthWidget { $0.clickAction = action.rawValue })

            #expect(twoMonthDiff.differingPixels == 0, "medium, \(action): \(twoMonthDiff.summary)")
            #expect(oneMonthDiff.differingPixels == 0, "small, \(action): \(oneMonthDiff.summary)")
        }
    }

    // MARK: - Every visible parameter reaches the pixels

    /// Each parameter reaches the pixels; what it draws is `ConfigurationChangeTests`.
    @Test func everyVisibleTwoMonthParameterChangesTheWidget() throws {
        let standard = try twoMonthWidget()
        let edits: [(name: String, edit: (CalendarConfigIntent) -> Void)] = [
            ("Second Month", { $0.companion = Companion.previous.rawValue }),
            // Monday-first host: `.monday` changes nothing.
            ("First Day of Week", { $0.firstWeekday = FirstWeekday.sunday.rawValue }),
            ("Week Numbers", { $0.showWeekNumbers = true }),
            ("Adjacent Month Days", { $0.showOutsideDays = false }),
            ("Show Year", { $0.showYear = false }),
            ("Month Number", { $0.monthNumber = MonthNumberDisplay.roman.rawValue }),
        ]

        for (name, edit) in edits {
            let diff = ImageComparator.compare(expected: standard, actual: try twoMonthWidget(edit))
            #expect(diff.differingPixels > 0, "\(name) did not change the two-month widget")
        }
    }

    /// Each parameter reaches the pixels; what it draws is `ConfigurationChangeTests`.
    @Test func everyVisibleOneMonthParameterChangesTheWidget() throws {
        let standard = try oneMonthWidget()
        let edits: [(name: String, edit: (SmallCalendarConfigIntent) -> Void)] = [
            ("Month", { $0.month = DisplayedMonth.next.rawValue }),
            ("First Day of Week", { $0.firstWeekday = FirstWeekday.sunday.rawValue }),
            ("Week Numbers", { $0.showWeekNumbers = true }),
            ("Adjacent Month Days", { $0.showOutsideDays = false }),
            ("Show Year", { $0.showYear = false }),
            ("Month Number", { $0.monthNumber = MonthNumberDisplay.roman.rawValue }),
        ]

        for (name, edit) in edits {
            let diff = ImageComparator.compare(expected: standard, actual: try oneMonthWidget(edit))
            #expect(diff.differingPixels > 0, "\(name) did not change the one-month widget")
        }
    }
}
