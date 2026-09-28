import Testing
import SwiftUI
import Foundation
@testable import LeapCore

/// L2 – what a widget configuration change does to the UI.
///
/// The provider holds no state, so the widget after an edit is exactly a fresh
/// render of the new settings. Each test renders the settings before and after
/// one change, through the entry path the provider uses, and asserts both
/// halves: the part that must change did, and nothing else moved.
///
/// Shared options run on both families. The two-month tile is measured one
/// month at a time – its halves – so an option that reaches only the first
/// month fails here rather than looking like a change.
///
/// The goldens pin each state's pixels; these pin the *difference* between
/// states, which survives a toolchain re-record. The intent-to-settings
/// mapping is tested in `LeapWidgetTests`; that the host re-renders a placed
/// widget after an edit is checked by hand (`docs/release-checklist.md`).
@Suite("Configuration changes", .tags(.layout), .serialized, .warmRenderer)
@MainActor
struct ConfigurationChangeTests {
    private typealias Band = LayoutInvariantTests.Band

    private struct Rendered {
        let entry: CalendarEntryModel
        let buffer: ImageComparator.Buffer
        let tile: WidgetGeometry
        let separators: Set<Int>
        let bands: [Band]

        var title: Band? { bands.first }
        /// Title and weekday headers; the six weeks follow.
        var weeks: ArraySlice<Band> { bands.dropFirst(2) }

        /// One column range per month: the whole tile, or its two halves.
        var months: [Range<Int>] {
            let width = buffer.width
            return tile == .small ? [0..<width] : [0..<width / 2, width / 2..<width]
        }

        /// Row bands of one month alone.
        func bands(in columns: Range<Int>) -> [Band] {
            ConfigurationChangeTests.rowBands(of: buffer, columns: columns, skipping: separators)
        }
    }

    private func render(_ settings: CalendarSettings,
                        tile: WidgetGeometry = .small,
                        calendar: Calendar = Fixtures.mondayFirst,
                        on day: DateComponents = Fixtures.referenceDay) throws -> Rendered {
        let entry = try GoldenCase.entry(settings: settings, calendar: calendar, reference: day)
        let image = try #require(RenderHarness.render(
            CalendarSurface(models: entry.models, yearLabel: entry.yearLabel),
            size: tile.tileSize, scheme: .light, layoutDirection: .leftToRight))
        let buffer = try #require(ImageComparator.buffer(of: image))
        let separators = Set(Self.separatorColumns(of: buffer))

        return Rendered(entry: entry, buffer: buffer, tile: tile, separators: separators,
                        bands: Self.rowBands(of: buffer, columns: 0..<buffer.width,
                                             skipping: separators))
    }

    nonisolated private static let tiles: [WidgetGeometry] = [.small, .medium]

    /// What each widget shows by default: the current month, or it and the next.
    private static func offsets(_ tile: WidgetGeometry) -> [Int] {
        tile == .small ? DisplayedMonth.current.monthOffsets : Companion.next.monthOffsets
    }

    /// One day column in pixels: the content box, split between the medium
    /// tile's two months and their 10 pt gap, over seven columns.
    private static func columnPitch(_ tile: WidgetGeometry) -> CGFloat {
        let width = tile.contentBox.width
        let month = tile == .small ? width : (width - 10) / 2
        return month / 7 * RenderHarness.scale
    }

    /// An 18 pt circle at scale 2 is ~1000 px; white two-digit text leaves ~800.
    private static let circle = 600

    // MARK: - First day of week

    /// `.system` on a Monday-first host must not look like a change at all.
    @Test(arguments: tiles)
    func systemFirstWeekdayOnAMondayHostMatchesMonday(tile: WidgetGeometry) throws {
        let offsets = Self.offsets(tile)
        let system = try render(CalendarSettings(monthOffsets: offsets, firstWeekday: .system),
                                tile: tile)
        let monday = try render(CalendarSettings(monthOffsets: offsets, firstWeekday: .monday),
                                tile: tile)

        let change = ImageComparator.change(from: system.buffer, to: monday.buffer)
        #expect(change == nil, "changed \(String(describing: change))")
    }

    @Test(arguments: tiles)
    func sundayFirstRotatesTheGridAndMovesTodayOneColumn(tile: WidgetGeometry) throws {
        let offsets = Self.offsets(tile)
        let monday = try render(CalendarSettings(monthOffsets: offsets, firstWeekday: .monday),
                                tile: tile)
        let sunday = try render(CalendarSettings(monthOffsets: offsets, firstWeekday: .sunday),
                                tile: tile)

        // Every month rotates, not only the first.
        #expect(monday.entry.models.count == offsets.count)
        for model in monday.entry.models {
            #expect(model.weekdayHeaders == ["M", "T", "W", "T", "F", "S", "S"], "\(model.title)")
            #expect(model.weekendColumns == [false, false, false, false, false, true, true])
        }
        for model in sunday.entry.models {
            #expect(model.weekdayHeaders == ["S", "M", "T", "W", "T", "F", "S"], "\(model.title)")
            #expect(model.weekendColumns == [true, false, false, false, false, false, true])
        }

        // Wednesday 12 August, in the first month either way.
        let before = try #require(monday.entry.models.first)
        let after = try #require(sunday.entry.models.first)
        #expect(Self.todayColumn(before) == 2)
        #expect(Self.todayColumn(after) == 3)

        #expect(monday.bands == sunday.bands, "rows moved: \(monday.bands) → \(sunday.bands)")
        for month in monday.months {
            #expect(ImageComparator.change(from: monday.buffer, to: sunday.buffer,
                                           columns: month) != nil,
                    "month at \(month) did not change")
        }

        let from = try #require(Self.todayCircleCentre(monday))
        let to = try #require(Self.todayCircleCentre(sunday))
        let pitch = Self.columnPitch(tile)
        #expect(abs(to - from - pitch) <= 2,
                "today moved \(to - from) px, a column is \(pitch) px")
    }

    /// The override carries its week rule: Monday is ISO, Sunday is US.
    @Test(arguments: tiles)
    func sundayFirstSwitchesTheWeekNumbersToo(tile: WidgetGeometry) throws {
        let offsets = Self.offsets(tile)
        let december = Fixtures.december
        let monday = try render(CalendarSettings(monthOffsets: offsets, firstWeekday: .monday,
                                                 showWeekNumbers: true),
                                tile: tile, on: december)
        let sunday = try render(CalendarSettings(monthOffsets: offsets, firstWeekday: .sunday,
                                                 showWeekNumbers: true),
                                tile: tile, on: december)

        let iso: [[Int]] = [[49, 50, 51, 52, 53, 1], [53, 1, 2, 3, 4, 5]]
        let us: [[Int]] = [[49, 50, 51, 52, 1, 2], [1, 2, 3, 4, 5, 6]]

        #expect(monday.entry.models.compactMap(\.weekNumbers) == Array(iso.prefix(offsets.count)))
        #expect(sunday.entry.models.compactMap(\.weekNumbers) == Array(us.prefix(offsets.count)))
        #expect(monday.bands == sunday.bands)
    }

    // MARK: - Week numbers

    @Test(arguments: tiles)
    func weekNumbersAddASeparatedColumnToEveryMonth(tile: WidgetGeometry) throws {
        let offsets = Self.offsets(tile)
        let off = try render(CalendarSettings(monthOffsets: offsets, showWeekNumbers: false),
                             tile: tile)
        let on = try render(CalendarSettings(monthOffsets: offsets, showWeekNumbers: true),
                            tile: tile)

        let numbers: [[Int]] = [[31, 32, 33, 34, 35, 36], [36, 37, 38, 39, 40, 41]]
        #expect(off.entry.models.allSatisfy { $0.weekNumbers == nil })
        #expect(on.entry.models.compactMap(\.weekNumbers) == Array(numbers.prefix(offsets.count)))
        #expect(off.bands.count == 8)
        #expect(on.bands.count == 8)

        #expect(off.separators.isEmpty)
        // One separator per month, each at its month's leading edge.
        let groups = Self.contiguousGroups(on.separators)
        #expect(groups.count == offsets.count, "separators at \(groups)")
        for (group, month) in zip(groups, on.months) {
            let leadingQuarter = month.lowerBound..<(month.lowerBound + month.count / 4)
            #expect(group.allSatisfy(leadingQuarter.contains),
                    "separator \(group) outside \(leadingQuarter)")
        }
    }

    // MARK: - Adjacent-month days

    /// Monday-first. August 2026: July fills week 1, September week 6.
    /// September 2026: August 31 in week 1, October 1–4 in week 5, all of
    /// week 6.
    @Test(arguments: tiles)
    func hidingOutsideDaysBlanksOnlyTheWeeksThatHoldThem(tile: WidgetGeometry) throws {
        let offsets = Self.offsets(tile)
        let shown = try render(CalendarSettings(monthOffsets: offsets, showOutsideDays: true),
                               tile: tile)
        let hidden = try render(CalendarSettings(monthOffsets: offsets, showOutsideDays: false),
                                tile: tile)
        let affectedWeeks: [Set<Int>] = [[0, 5], [0, 4, 5]]

        #expect(shown.entry.models.map(\.weeks) == hidden.entry.models.map(\.weeks))
        // Tops, not bottoms: the grey digits' anti-aliased last row goes with them.
        #expect(shown.bands.map(\.top) == hidden.bands.map(\.top))

        let weeks = Array(shown.weeks)
        #expect(weeks.count == 6)
        for (month, affected) in zip(shown.months, affectedWeeks) {
            let change = try #require(
                ImageComparator.change(from: shown.buffer, to: hidden.buffer, columns: month),
                "month at \(month): hiding outside days drew nothing")
            let allowed = affected.map { weeks[$0].top...weeks[$0].bottom }
            let stray = change.rows.filter { row in !allowed.contains { $0.contains(row) } }
            #expect(stray.isEmpty,
                    "month at \(month): rows \(Array(stray)) changed outside weeks \(affected.sorted())")
        }
    }

    /// Sunday-first. February 2026 ends in two all-March rows; March 2026 in
    /// one all-April row. Hidden, those rows lose their week numbers too and
    /// draw nothing at all.
    @Test(arguments: tiles)
    func hidingOutsideDaysAlsoHidesTheWeekNumbersOfBlankRows(tile: WidgetGeometry) throws {
        let offsets = Self.offsets(tile)
        let february = DateComponents(year: 2026, month: 2, day: 10, hour: 12)
        let shown = try render(CalendarSettings(monthOffsets: offsets, showWeekNumbers: true,
                                                showOutsideDays: true),
                               tile: tile, calendar: Fixtures.sundayFirst, on: february)
        let hidden = try render(CalendarSettings(monthOffsets: offsets, showWeekNumbers: true,
                                                 showOutsideDays: false),
                                tile: tile, calendar: Fixtures.sundayFirst, on: february)
        // Title, headers, then the weeks that keep a day of their own month.
        let expected = [6, 7]

        #expect(shown.entry.models.allSatisfy { $0.weekNumbers?.count == 6 })
        for (month, count) in zip(shown.months, expected) {
            let before = shown.bands(in: month)
            let after = hidden.bands(in: month)

            #expect(before.count == 8, "month at \(month) shown: \(before)")
            #expect(after.count == count, "month at \(month) hidden: \(after)")
            #expect(Array(before.prefix(count)) == after, "month at \(month): rows moved")
        }
    }

    // MARK: - Year label

    @Test(arguments: tiles)
    func turningTheYearOffChangesOnlyTheTrailingTitle(tile: WidgetGeometry) throws {
        let offsets = Self.offsets(tile)
        let on = try render(CalendarSettings(monthOffsets: offsets, showYear: true), tile: tile)
        let off = try render(CalendarSettings(monthOffsets: offsets, showYear: false), tile: tile)

        #expect(on.entry.yearLabel == "\u{2019}26")
        #expect(off.entry.yearLabel == nil)
        #expect(Array(on.bands.dropFirst()) == Array(off.bands.dropFirst()))

        let change = try #require(ImageComparator.change(from: on.buffer, to: off.buffer),
                                  "the year toggle drew nothing")
        let title = try #require(on.title)
        #expect(change.rows.allSatisfy { (title.top...title.bottom).contains($0) },
                "changed \(change), title band \(title)")
        #expect(change.columns.lowerBound > on.buffer.width / 2, "changed \(change)")
    }

    // MARK: - Month number

    @Test(arguments: tiles)
    func theMonthNumberChangesOnlyEveryTitle(tile: WidgetGeometry) throws {
        let offsets = Self.offsets(tile)
        let off = try render(CalendarSettings(monthOffsets: offsets, monthNumber: .off), tile: tile)
        let arabic = try render(CalendarSettings(monthOffsets: offsets, monthNumber: .arabic),
                                tile: tile)
        let roman = try render(CalendarSettings(monthOffsets: offsets, monthNumber: .roman),
                               tile: tile)

        #expect(off.entry.models.allSatisfy { $0.monthNumberLabel == nil })
        #expect(arabic.entry.models.map(\.monthNumberLabel)
                == Array(["8", "9"].prefix(offsets.count)))
        #expect(roman.entry.models.map(\.monthNumberLabel)
                == Array(["VIII", "IX"].prefix(offsets.count)))

        let title = try #require(off.title)
        for (name, numbered) in [("arabic", arabic), ("roman", roman)] {
            #expect(numbered.bands == off.bands, "\(name): rows moved")

            for month in off.months {
                let change = try #require(
                    ImageComparator.change(from: off.buffer, to: numbered.buffer, columns: month),
                    "\(name): month at \(month) drew no number")
                #expect(change.rows.allSatisfy { (title.top...title.bottom).contains($0) },
                        "\(name): changed \(change), title band \(title)")
            }
        }

        #expect(ImageComparator.change(from: arabic.buffer, to: roman.buffer) != nil,
                "arabic and roman render the same")
    }

    // MARK: - Which month (small)

    @Test(arguments: [(DisplayedMonth.current, "AUGUST", true),
                      (.next, "SEPTEMBER", false),
                      (.previous, "JULY", false)])
    func theDisplayedMonthDecidesTheTitleAndTheTodayMarker(month: DisplayedMonth,
                                                          title: String,
                                                          marksToday: Bool) throws {
        let rendered = try render(CalendarSettings(monthOffsets: month.monthOffsets))
        let red = try Self.todayRed(rendered)

        #expect(rendered.entry.models.map(\.title) == [title])
        #expect(rendered.entry.yearLabel == "\u{2019}26")
        if marksToday {
            #expect(red.leading + red.trailing > Self.circle, "no today circle: \(red)")
        } else {
            #expect(red.leading + red.trailing == 0, "stray today circle: \(red)")
        }
    }

    @Test func nextMonthFromDecemberCrossesIntoTheNewYear() throws {
        let current = try render(CalendarSettings(monthOffsets: DisplayedMonth.current.monthOffsets),
                                 on: Fixtures.december)
        let next = try render(CalendarSettings(monthOffsets: DisplayedMonth.next.monthOffsets),
                              on: Fixtures.december)

        #expect(current.entry.models.map(\.title) == ["DECEMBER"])
        #expect(current.entry.yearLabel == "\u{2019}26")
        #expect(next.entry.models.map(\.title) == ["JANUARY"])
        #expect(next.entry.yearLabel == "\u{2019}27")

        let red = try Self.todayRed(next)
        #expect(red.leading + red.trailing == 0, "January marks a day in December: \(red)")
    }

    // MARK: - Second month (medium)

    @Test func thePreviousCompanionPutsTodayInTheTrailingMonth() throws {
        let next = try render(CalendarSettings(monthOffsets: Companion.next.monthOffsets),
                              tile: .medium)
        let previous = try render(CalendarSettings(monthOffsets: Companion.previous.monthOffsets),
                                  tile: .medium)

        #expect(next.entry.models.map(\.title) == ["AUGUST", "SEPTEMBER"])
        #expect(previous.entry.models.map(\.title) == ["JULY", "AUGUST"])
        // The label follows the current month, wherever it sits.
        #expect(next.entry.yearLabel == "\u{2019}26")
        #expect(previous.entry.yearLabel == "\u{2019}26")
        #expect(next.bands == previous.bands)

        let before = try Self.todayRed(next)
        let after = try Self.todayRed(previous)
        #expect(before.leading > Self.circle && before.trailing == 0, "next: \(before)")
        #expect(after.leading == 0 && after.trailing > Self.circle, "previous: \(after)")
    }

    @Test func thePreviousCompanionInJanuaryLabelsTheNewYear() throws {
        let january = DateComponents(year: 2027, month: 1, day: 10, hour: 12)
        let rendered = try render(CalendarSettings(monthOffsets: Companion.previous.monthOffsets),
                                  tile: .medium, on: january)

        #expect(rendered.entry.models.map(\.title) == ["DECEMBER", "JANUARY"])
        #expect(rendered.entry.yearLabel == "\u{2019}27")

        let red = try Self.todayRed(rendered)
        #expect(red.leading == 0 && red.trailing > Self.circle, "\(red)")
    }

    // MARK: - Click action

    /// Only the click target may change. The pixels of the widget-side
    /// `WidgetClickSurface` are tested in `WidgetViewRenderTests`.
    @Test(arguments: ClickAction.allCases, tiles)
    func theClickActionNeverChangesWhatIsDrawn(action: ClickAction, tile: WidgetGeometry) throws {
        let offsets = Self.offsets(tile)
        let standard = try render(CalendarSettings(monthOffsets: offsets), tile: tile)
        let changed = try render(CalendarSettings(monthOffsets: offsets, clickAction: action),
                                 tile: tile)

        #expect(changed.entry.clickAction == action)
        #expect(changed.entry.models == standard.entry.models)
        #expect(changed.entry.yearLabel == standard.entry.yearLabel)
        #expect(ImageComparator.change(from: standard.buffer, to: changed.buffer) == nil)
    }

    // MARK: - Measuring

    private static func todayColumn(_ model: MonthModel) -> Int? {
        model.weeks.lazy.compactMap { $0.firstIndex(where: \.isToday) }.first
    }

    /// The title, month number and year label are red too; below the weekday
    /// headers the today circle is the only red there is.
    private static func todayRed(_ rendered: Rendered) throws -> (leading: Int, trailing: Int) {
        let headers = try #require(rendered.bands.dropFirst().first, "no weekday header band")
        var leading = 0
        var trailing = 0
        let buffer = rendered.buffer
        let middle = buffer.width / 2

        for y in (headers.bottom + 1)..<buffer.height {
            for x in 0..<buffer.width where isRed(buffer, x: x, y: y) {
                if x < middle { leading += 1 } else { trailing += 1 }
            }
        }

        return (leading, trailing)
    }

    /// Mean x of the today circle's red, below the weekday headers.
    private static func todayCircleCentre(_ rendered: Rendered) -> CGFloat? {
        guard let headers = rendered.bands.dropFirst().first else { return nil }

        let buffer = rendered.buffer
        var sum = 0
        var count = 0
        for y in (headers.bottom + 1)..<buffer.height {
            for x in 0..<buffer.width where isRed(buffer, x: x, y: y) {
                sum += x
                count += 1
            }
        }

        return count == 0 ? nil : CGFloat(sum) / CGFloat(count)
    }

    private static func isRed(_ buffer: ImageComparator.Buffer, x: Int, y: Int) -> Bool {
        let offset = (y * buffer.width + x) * 4

        return buffer.bytes[offset] > 200 && buffer.bytes[offset + 1] < 100
            && buffer.bytes[offset + 2] < 100
    }

    /// The week-number separator: the only ink that runs unbroken through
    /// several rows. A digit is ~15 px tall; three rows are ~100.
    private static func separatorColumns(of buffer: ImageComparator.Buffer) -> [Int] {
        let background = background(of: buffer)

        return (0..<buffer.width).filter { x in
            var run = 0
            for y in 0..<buffer.height {
                run = isInk(buffer, x: x, y: y, background: background) ? run + 1 : 0
                if run >= 100 { return true }
            }
            return false
        }
    }

    /// A 1 pt line is two adjacent columns at scale 2; each run is one line.
    private static func contiguousGroups(_ columns: Set<Int>) -> [[Int]] {
        columns.sorted().reduce(into: [[Int]]()) { groups, x in
            if let last = groups.last?.last, x == last + 1 {
                groups[groups.count - 1].append(x)
            } else {
                groups.append([x])
            }
        }
    }

    /// `LayoutInvariantTests.rowBands`, blind to the separator – which would
    /// otherwise bridge every week into one band.
    nonisolated private static func rowBands(of buffer: ImageComparator.Buffer,
                                                 columns: Range<Int>,
                                                 skipping skipped: Set<Int>) -> [Band] {
        let background = background(of: buffer)
        var bands: [Band] = []
        var start: Int?

        for y in 0..<buffer.height {
            let inked = columns.contains { x in
                !skipped.contains(x) && isInk(buffer, x: x, y: y, background: background)
            }

            if inked, start == nil { start = y }
            if !inked, let from = start {
                bands.append(Band(top: from, bottom: y - 1))
                start = nil
            }
        }
        if let from = start { bands.append(Band(top: from, bottom: buffer.height - 1)) }

        return bands
    }

    nonisolated private static func background(of buffer: ImageComparator.Buffer) -> (Int, Int, Int) {
        (Int(buffer.bytes[0]), Int(buffer.bytes[1]), Int(buffer.bytes[2]))
    }

    /// The same threshold `LayoutInvariantTests` measures bands with.
    nonisolated private static func isInk(_ buffer: ImageComparator.Buffer, x: Int, y: Int,
                                          background: (Int, Int, Int)) -> Bool {
        let offset = (y * buffer.width + x) * 4

        return abs(Int(buffer.bytes[offset]) - background.0) > 16
            || abs(Int(buffer.bytes[offset + 1]) - background.1) > 16
            || abs(Int(buffer.bytes[offset + 2]) - background.2) > 16
    }
}
