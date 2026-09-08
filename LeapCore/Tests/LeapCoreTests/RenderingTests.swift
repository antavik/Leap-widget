import Testing
import SwiftUI
@testable import LeapCore

/// Native `ImageRenderer` smoke tests (no external snapshot library, G11).
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
    let image = try #require(renderedImage(MonthGridView(model: model),
                                           size: CGSize(width: 155, height: 155)))
    #expect(image.size.width > 0)
}

/// The small widget's path: one model plus the displayed month's year label.
@Test @MainActor func singleMonthWithYearLabelRenders() throws {
    let calendar = fixtureCalendar()
    let january = calendar.date(from: DateComponents(year: 2027, month: 1, day: 10))!
    let december = monthModel(containing: january, offset: -1, calendar: calendar,
                              today: january, options: MonthOptions())
    let image = renderedImage(
        MultiMonthView(models: [december], yearLabel: yearLabel(forYear: december.year)),
        size: CGSize(width: 155, height: 155))
    #expect(image != nil)
}

/// The superscript title row at both type scales, with the widest label the
/// design allows (Roman + week numbers).
@Test @MainActor func monthNumberRendersAtBothScales() throws {
    let calendar = fixtureCalendar()
    let september = calendar.date(from: DateComponents(year: 2026, month: 9, day: 12))!
    let model = monthModel(containing: september, offset: 0, calendar: calendar,
                           today: september,
                           options: MonthOptions(showWeekNumbers: true,
                                                 monthNumberStyle: .roman))
    #expect(model.monthNumberLabel == "IX")
    for metrics in [Theme.small, Theme.medium] {
        let image = renderedImage(MonthGridView(model: model, metrics: metrics),
                                  size: CGSize(width: 155, height: 155))
        #expect(image != nil)
    }
}

@Test @MainActor func multiMonthWithMonthNumbersRenders() throws {
    let calendar = fixtureCalendar()
    let december = calendar.date(from: DateComponents(year: 2026, month: 12, day: 15))!
    let row = monthRow(containing: december,
                       offsets: [0, 1],
                       showYear: true,
                       builder: MonthModelBuilder(
                           calendar: calendar,
                           options: MonthOptions(monthNumberStyle: .arabic)))
    let image = renderedImage(
        MultiMonthView(models: row.models, yearLabel: row.yearLabel),
        size: CGSize(width: 330, height: 155))
    #expect(image != nil)
}
