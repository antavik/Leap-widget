import Testing
import SwiftUI
@testable import QuaterlyCore

/// Native `ImageRenderer` smoke tests (§5 — no external snapshot library, G11).
@MainActor
private func renderedImage<V: View>(_ view: V, size: CGSize) -> NSImage? {
    let renderer = ImageRenderer(content: view.frame(width: size.width, height: size.height))
    renderer.scale = 2
    return renderer.nsImage
}

private func fixtureCalendar() -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.locale = Locale(identifier: "en_US")
    calendar.firstWeekday = 2
    calendar.timeZone = TimeZone(identifier: "GMT")!
    return calendar
}

@Test @MainActor func monthGridRenders() throws {
    let calendar = fixtureCalendar()
    let today = calendar.date(from: DateComponents(year: 2026, month: 8, day: 12))!
    let model = monthModel(containing: today, offset: 0, calendar: calendar,
                           today: today,
                           options: MonthOptions(showWeekNumbers: true))
    let image = renderedImage(MonthGridView(model: model), size: CGSize(width: 155, height: 155))
    #expect(image != nil)
    #expect(image!.size.width > 0)
}

@Test @MainActor func multiMonthRendersAcrossYearBoundary() throws {
    let calendar = fixtureCalendar()
    let december = calendar.date(from: DateComponents(year: 2026, month: 12, day: 15))!
    let config = WidgetConfig(span: 2, companionPrevious: false, options: MonthOptions())
    let image = renderedImage(
        MultiMonthView(date: december, family: .medium, config: config, calendar: calendar),
        size: CGSize(width: 330, height: 155))
    #expect(image != nil)
}
