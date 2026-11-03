import Testing
import Foundation
@testable import LeapCore

/// Every option→model mapping the widget performs, parameterized over
/// `allCases` so a new case cannot slip through untested.
@Suite("Widget configuration")
struct WidgetConfigurationTests {

    // MARK: - Raw values

    // Persisted configuration: changing one silently resets somebody's widget.
    @Test func rawValuesArePinned() {
        #expect(DisplayedMonth.allCases.map(\.rawValue) == ["current", "next", "previous"])
        #expect(Companion.allCases.map(\.rawValue) == ["next", "previous"])
        #expect(FirstWeekday.allCases.map(\.rawValue) == ["system", "monday", "sunday"])
        #expect(MonthNumberDisplay.allCases.map(\.rawValue) == ["off", "arabic", "roman"])
        #expect(ClickAction.allCases.map(\.rawValue)
                == ["appleCalendar", "fantastical", "googleCalendar", "doNothing"])
    }

    // MARK: - Month selection

    @Test(arguments: [(Companion.next, [0, 1]), (.previous, [-1, 0])])
    func companionPicksItsMonthRow(companion: Companion, offsets: [Int]) {
        #expect(companion.monthOffsets == offsets)
    }

    @Test(arguments: [(DisplayedMonth.current, [0]), (.next, [1]), (.previous, [-1])])
    func displayedMonthPicksOneMonth(month: DisplayedMonth, offsets: [Int]) {
        #expect(month.monthOffsets == offsets)
        #expect(month.offset == offsets[0])
    }

    // MARK: - First weekday

    @Test(arguments: [(FirstWeekday.system, nil), (.sunday, 1), (.monday, 2)])
    func firstWeekdayMapsToACalendarWeekday(option: FirstWeekday, weekday: Int?) {
        #expect(option.calendarWeekday == weekday)
    }

    // MARK: - Month number

    @Test(arguments: [(MonthNumberDisplay.off, nil),
                      (.arabic, MonthNumberStyle.arabic),
                      (.roman, .roman)])
    func monthNumberMapsToAStyle(option: MonthNumberDisplay, style: MonthNumberStyle?) {
        #expect(option.style == style)
    }

    // MARK: - Settings → MonthOptions

    @Test func settingsCarryEveryOptionIntoTheModel() {
        let settings = CalendarSettings(monthOffsets: [0, 1],
                                        firstWeekday: .monday,
                                        showWeekNumbers: true,
                                        showOutsideDays: false,
                                        showYear: false,
                                        monthNumber: .roman,
                                        clickAction: .fantastical)

        #expect(settings.monthOptions == MonthOptions(firstWeekday: 2,
                                                      showWeekNumbers: true,
                                                      showOutsideDays: false,
                                                      monthNumberStyle: .roman))
        #expect(settings.clickAction == .fantastical)
        #expect(settings.showYear == false)
    }

    /// A changed default shows up here rather than in a user's widget.
    @Test func declaredDefaultsMatchTheDocumentedOnes() {
        let settings = CalendarSettings(monthOffsets: [0, 1])

        #expect(settings.firstWeekday == .system)
        #expect(settings.showWeekNumbers == false)
        #expect(settings.showOutsideDays == true)
        #expect(settings.showYear == true)
        #expect(settings.monthNumber == .off)
        #expect(settings.clickAction == .appleCalendar)
        #expect(settings.monthOptions == MonthOptions())
    }

    @Test(arguments: FirstWeekday.allCases)
    func everyFirstWeekdayReachesTheGrid(option: FirstWeekday) throws {
        let settings = CalendarSettings(monthOffsets: [0], firstWeekday: option)
        let calendar = Fixtures.sundayFirst
        let today = try Fixtures.date(2026, 8, 12, in: calendar)
        let model = monthModel(containing: today, offset: 0, calendar: calendar,
                               today: today, options: settings.monthOptions)
        let expected = option.calendarWeekday ?? calendar.firstWeekday

        #expect(model.weekdayHeaders.first
                == calendar.veryShortStandaloneWeekdaySymbols[expected - 1])
    }
}
