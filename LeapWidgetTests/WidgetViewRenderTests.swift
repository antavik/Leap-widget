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

    private func render(_ view: some View, tile: WidgetGeometry) throws -> Buffer {
        let image = try #require(RenderHarness.render(view, size: tile.tile, scheme: .light,
                                                      layoutDirection: .leftToRight))
        return try #require(ImageComparator.buffer(of: image))
    }

    private func entry(_ config: some CalendarConfiguration) throws -> CalendarEntry {
        let date = try Fixtures.date(2026, 8, 12, in: Self.calendar)
        return CalendarEntry(date: date, config: config, calendar: Self.calendar)
    }

    private func twoMonths(_ edit: (CalendarConfigIntent) -> Void = { _ in }) throws -> Buffer {
        let intent = CalendarConfigIntent()
        edit(intent)
        return try render(CalendarWidgetView(entry: entry(intent)), tile: .medium)
    }

    private func oneMonth(_ edit: (SmallCalendarConfigIntent) -> Void = { _ in }) throws -> Buffer {
        let intent = SmallCalendarConfigIntent()
        edit(intent)
        return try render(CalendarWidgetView(entry: entry(intent)), tile: .small)
    }

    // MARK: - The widget view draws what the goldens pin

    /// Ties the goldens, which render `CalendarSurface`, to the shipping view.
    @Test func theWidgetViewDrawsExactlyTheSurface() throws {
        let medium = try entry(CalendarConfigIntent())
        let small = try entry(SmallCalendarConfigIntent())

        for (entry, tile) in [(medium, WidgetGeometry.medium), (small, .small)] {
            let widget = try render(CalendarWidgetView(entry: entry), tile: tile)
            let surface = try render(CalendarSurface(models: entry.models,
                                                     yearLabel: entry.yearLabel),
                                     tile: tile)

            #expect(!ImageComparator.isFlat(widget), "\(tile): the widget drew nothing")
            #expect(ImageComparator.compare(surface, widget).differingPixels == 0,
                    "\(tile): \(ImageComparator.compare(surface, widget).summary)")
        }
    }

    // MARK: - Click action

    /// `widgetURL`, or an inert `Button` for "Nothing" – neither may show.
    @Test func theClickActionNeverChangesThePixels() throws {
        let medium = try twoMonths { $0.clickAction = .appleCalendar }
        let small = try oneMonth { $0.clickAction = .appleCalendar }

        for action in ClickAction.allCases {
            let twoMonthDiff = ImageComparator.compare(medium,
                                                       try twoMonths { $0.clickAction = action })
            let oneMonthDiff = ImageComparator.compare(small,
                                                       try oneMonth { $0.clickAction = action })

            #expect(twoMonthDiff.differingPixels == 0, "medium, \(action): \(twoMonthDiff.summary)")
            #expect(oneMonthDiff.differingPixels == 0, "small, \(action): \(oneMonthDiff.summary)")
        }
    }

    // MARK: - Every visible parameter reaches the pixels

    /// Each parameter reaches the pixels; what it draws is `ConfigurationChangeTests`.
    @Test func everyVisibleTwoMonthParameterChangesTheWidget() throws {
        let standard = try twoMonths()
        let edits: [(String, (CalendarConfigIntent) -> Void)] = [
            ("Second Month", { $0.companion = .previous }),
            // Monday-first host: `.monday` changes nothing.
            ("First Day of Week", { $0.firstWeekday = .sunday }),
            ("Week Numbers", { $0.showWeekNumbers = true }),
            ("Adjacent Month Days", { $0.showOutsideDays = false }),
            ("Show Year", { $0.showYear = false }),
            ("Month Number", { $0.monthNumber = .roman }),
        ]

        for (name, edit) in edits {
            #expect(ImageComparator.compare(standard, try twoMonths(edit)).differingPixels > 0,
                    "\(name) did not change the two-month widget")
        }
    }

    @Test func everyVisibleOneMonthParameterChangesTheWidget() throws {
        let standard = try oneMonth()
        let edits: [(String, (SmallCalendarConfigIntent) -> Void)] = [
            ("Month", { $0.month = .next }),
            ("First Day of Week", { $0.firstWeekday = .sunday }),
            ("Week Numbers", { $0.showWeekNumbers = true }),
            ("Adjacent Month Days", { $0.showOutsideDays = false }),
            ("Show Year", { $0.showYear = false }),
            ("Month Number", { $0.monthNumber = .roman }),
        ]

        for (name, edit) in edits {
            #expect(ImageComparator.compare(standard, try oneMonth(edit)).differingPixels > 0,
                    "\(name) did not change the one-month widget")
        }
    }
}
