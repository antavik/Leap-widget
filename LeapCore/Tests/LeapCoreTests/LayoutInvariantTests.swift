import Testing
import SwiftUI
import Foundation
@testable import LeapCore

@Suite("Layout invariants", .tags(.layout), .serialized, .warmRenderer)
@MainActor
struct LayoutInvariantTests {

    // MARK: - Helpers

    private func models(_ reference: DateComponents,
                        today: DateComponents? = nil,
                        offsets: [Int] = [0],
                        calendar: Calendar = Fixtures.mondayFirst,
                        options: MonthOptions = MonthOptions())
    throws -> (models: [MonthModel], yearLabel: String?) {
        let date = try #require(calendar.date(from: reference))
        let todayDate = try today.map { try #require(calendar.date(from: $0)) } ?? date
        let builder = MonthModelBuilder(calendar: calendar, options: options)
        let built = offsets.map {
            builder.model(containing: date, offset: $0, today: todayDate)
        }
        // Follows the offset-0 month, as `monthRow` does: `first` agrees only
        // while the row starts at offset 0.
        let current = offsets.firstIndex(of: 0) ?? 0

        return (built, built.indices.contains(current)
            ? yearLabel(forYear: built[current].year)
            : nil)
    }

    private func buffer(_ row: (models: [MonthModel], yearLabel: String?),
                        tile: WidgetGeometry = .small,
                        scheme: ColorScheme = .light,
                        layoutDirection: LayoutDirection = .leftToRight)
    throws -> ImageComparator.Buffer {
        let image = try #require(
            RenderHarness.render(CalendarSurface(models: row.models,
                                                 yearLabel: row.yearLabel),
                                 size: tile.tile,
                                 scheme: scheme,
                                 layoutDirection: layoutDirection),
            "render produced no image")

        return try #require(ImageComparator.buffer(of: image))
    }

    private func intrinsicSize(_ row: (models: [MonthModel], yearLabel: String?),
                               scheme: ColorScheme = .light) throws -> CGSize {
        try #require(RenderHarness.intrinsicSize(
            MultiMonthView(models: row.models, yearLabel: row.yearLabel),
            scheme: scheme))
    }

    private static let august = Fixtures.referenceDay

    // MARK: - Opacity, on every case in the matrix

    @Test(arguments: GoldenCase.all)
    func everyComposedRenderIsFullyOpaque(_ golden: GoldenCase) throws {
        let rendered = try golden.render()
        let buffer = try #require(ImageComparator.buffer(of: rendered))

        #expect(ImageComparator.isFullyOpaque(buffer),
                """
                \(golden.id): \(ImageComparator.opaquePixelCount(buffer)) of \
                \(buffer.pixelCount) pixels are opaque
                """)
    }

    // MARK: - Something is actually drawn

    @Test func lightAndDarkRendersDifferAndNeitherIsFlat() throws {
        let row = try models(Self.august)
        let light = try buffer(row, scheme: .light)
        let dark = try buffer(row, scheme: .dark)

        #expect(ImageComparator.compare(light, dark).differingPixels > 0)
        #expect(!ImageComparator.isFlat(light))
        #expect(!ImageComparator.isFlat(dark))
    }

    // MARK: - The week-number column

    @Test func weekNumbersAddTheDocumentedColumnFootprint() throws {
        let plain = try intrinsicSize(models(Self.august))
        let numbered = try intrinsicSize(
            models(Self.august, options: MonthOptions(showWeekNumbers: true)))

        #expect(numbered.width - plain.width
                == Theme.small.weekNumberColumnWidth + 7)
    }

    @Test func weekNumbersShiftTheGridHeightByThreePoints() throws {
        let plain = try intrinsicSize(models(Self.august))
        let numbered = try intrinsicSize(
            models(Self.august, options: MonthOptions(showWeekNumbers: true)))

        #expect(numbered.height - plain.height == 3)
    }

    // MARK: - Row geometry

    @Test func gridHeightIsIdenticalWithOutsideDaysShownAndHidden() throws {
        let shown = try intrinsicSize(models(Self.august))
        let hidden = try intrinsicSize(
            models(Self.august, options: MonthOptions(showOutsideDays: false)))

        #expect(shown.height == hidden.height)
        #expect(shown.width == hidden.width)

        // February 2026 Sunday-first ends in two blank rows, where a
        // collapsing placeholder shows up first.
        let february = DateComponents(year: 2026, month: 2, day: 10, hour: 12)
        let full = try intrinsicSize(models(february, calendar: Fixtures.sundayFirst))
        let blanked = try intrinsicSize(
            models(february, calendar: Fixtures.sundayFirst,
                   options: MonthOptions(showOutsideDays: false)))

        #expect(full.height == blanked.height)
    }

    @Test func sixRowsAreDrawnAtAConstantPitch() throws {
        let bands = try Self.rowBands(of: buffer(models(Self.august)))

        // Title, weekday headers, then six weeks.
        #expect(bands.count == 8, "bands=\(bands)")

        let weeks = bands.suffix(6)
        let pitches = zip(weeks, weeks.dropFirst()).map { $1.midpoint - $0.midpoint }
        let spread = (pitches.max() ?? 0) - (pitches.min() ?? 0)

        #expect(pitches.count == 5)
        #expect(spread <= 1, "row pitch varies by \(spread) px: \(pitches)")
    }

    // MARK: - The today marker

    @Test func theTodayCircleLandsOnlyInTheOffsetZeroMonth() throws {
        let withToday = try buffer(models(Self.august, offsets: [0, 1],
                                          calendar: Fixtures.mondayFirst),
                                   tile: .medium)
        let withoutToday = try buffer(
            models(Self.august,
                   today: DateComponents(year: 2026, month: 5, day: 4, hour: 12),
                   offsets: [0, 1]),
            tile: .medium)

        let added = Self.redPixelsPerHalf(withToday)
        let baseline = Self.redPixelsPerHalf(withoutToday)

        // The circle is 18 pt at scale 2 — over 800 pixels of solid red.
        #expect(added.leading - baseline.leading > 800)
        #expect(added.trailing == baseline.trailing)
    }

    // MARK: - The superscript month number

    @Test(arguments: [MonthNumberStyle.arabic, .roman])
    func theMonthNumberIsCapAlignedWithTheTitle(style: MonthNumberStyle) throws {
        let plainBuffer = try buffer(models(Self.august))
        let numberedBuffer = try buffer(
            models(Self.august, options: MonthOptions(monthNumberStyle: style)))

        // Required, not optional-compared: two empty band lists are equal, so
        // this would pass on a render that drew nothing.
        let plain = try #require(Self.rowBands(of: plainBuffer).first)
        let numbered = try #require(Self.rowBands(of: numberedBuffer).first)

        // Too high, and the taller title band pushes the whole grid down.
        #expect(plain.top == numbered.top,
                "title band moved: \(plain) → \(numbered)")

        // Too low, and the number sinks towards the baseline inside that band.
        let superscriptTop = try #require(
            Self.firstDifferingRow(plainBuffer, numberedBuffer),
            "the month number drew nothing")

        // One device pixel at scale 2 — the raised run snaps its raster origin.
        #expect((0...1).contains(superscriptTop - plain.top),
                """
                \(style): the month number's cap top is \(superscriptTop) px \
                against a title cap top of \(plain.top) px
                """)
    }

    // MARK: - Clipping

    /// Tightest measured case: `de_DE` December with Roman numerals and week
    /// numbers, at 143×164 pt in a 170×170 tile.
    @Test(arguments: GoldenCase.widgetCases)
    func renderedContentFitsTheContentBox(_ golden: GoldenCase) throws {
        let tile = try #require(golden.tile)
        let content = try golden.intrinsicContentSize()
        let box = tile.contentBox

        #expect(content.width <= box.width,
                "\(golden.id): \(content.width) pt wide in a \(box.width) pt box")
        #expect(content.height <= box.height,
                "\(golden.id): \(content.height) pt tall in a \(box.height) pt box")
    }

    // MARK: - Direction and type size

    @Test func rightToLeftRendersDifferentlyFromLeftToRight() throws {
        let row = try models(Self.august)
        let ltr = try buffer(row, layoutDirection: .leftToRight)
        let rtl = try buffer(row, layoutDirection: .rightToLeft)

        #expect(ImageComparator.compare(ltr, rtl).differingPixels > 0)
    }

    @Test func accessibilityFiveRendersIdenticallyToTheDefault() throws {
        let row = try models(Self.august)
        let standard = try buffer(row)
        let image = try #require(RenderHarness.render(
            CalendarSurface(models: row.models, yearLabel: row.yearLabel)
                .dynamicTypeSize(.accessibility5),
            size: WidgetGeometry.small.tile,
            scheme: .light,
            layoutDirection: .leftToRight))
        let enlarged = try #require(ImageComparator.buffer(of: image))

        #expect(ImageComparator.compare(standard, enlarged).differingPixels == 0)
    }

    // MARK: - Edge guards

    @Test func aRowWithNoMonthsStillRenders() throws {
        let buffer = try buffer((models: [], yearLabel: nil))

        #expect(ImageComparator.isFullyOpaque(buffer))
        #expect(ImageComparator.isFlat(buffer))   // nothing to draw, but a valid tile
    }

    // MARK: - Onboarding

    @Test func onboardingHoldsItsDeclaredWidth() throws {
        let rendered = try #require(RenderHarness.intrinsicSize(
            OnboardingView().environment(\.locale, Locale(identifier: "en_US")),
            scheme: .light))

        #expect(rendered.width == OnboardingView.width)
    }

    /// What the deleted `de_DE` golden was meant to prove, asserted where it
    /// can fail: both catalogues ship `en` only, so that comparison held by
    /// equality. Driving the text length needs no translations.
    @Test func longerStepTextGrowsTheStepInsteadOfClipping() throws {
        func height(of text: String) throws -> CGSize {
            let step = OnboardingStep(symbol: "bell.badge",
                                      title: LocalizedStringResource("Title"),
                                      text: LocalizedStringResource(stringLiteral: text))

            return try #require(RenderHarness.intrinsicSize(
                OnboardingStepView(step: step, number: 1, total: 3)
                    .frame(width: OnboardingView.width),
                scheme: .light))
        }

        let short = try height(of: "Short.")
        let long = try height(of: String(repeating: "A rather long sentence. ", count: 8))

        #expect(short.width == OnboardingView.width)
        #expect(long.width == OnboardingView.width)
        #expect(long.height > short.height,
                "\(long.height) pt is not taller than \(short.height) pt — the text truncated")
    }

    @Test func onboardingDrawsThreeSteps() throws {
        let rendered = try #require(RenderHarness.renderFlexibleHeight(
            OnboardingView(),
            width: OnboardingView.width,
            scheme: .light,
            layoutDirection: .leftToRight))
        let buffer = try #require(ImageComparator.buffer(of: rendered))

        // One accent-tinted SF Symbol per step. A symbol can draw in several
        // strokes, so bands closer than a step gap count as one glyph.
        #expect(Self.accentBands(of: buffer, mergedWithin: 20).count == 3)
    }

    // MARK: - Measuring

    struct Band: Equatable, CustomStringConvertible {
        let top: Int
        let bottom: Int

        var midpoint: Int { (top + bottom) / 2 }
        var description: String { "\(top)…\(bottom)" }
    }

    /// Horizontal bands of drawn pixels, top to bottom: one per text row.
    static func rowBands(of buffer: ImageComparator.Buffer,
                         columns: Range<Int>? = nil) -> [Band] {
        let columns = columns ?? 0..<buffer.width
        // Read once: inside the per-pixel test this allocated a three-element
        // `Array` per pixel of every render.
        let background = (Int(buffer.bytes[0]), Int(buffer.bytes[1]), Int(buffer.bytes[2]))
        var bands: [Band] = []
        var start: Int?

        for y in 0..<buffer.height {
            let inked = columns.contains { x in
                isInk(buffer, x: x, y: y, background: background)
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

    /// The onboarding step symbols are the only blue the window draws.
    static func accentBands(of buffer: ImageComparator.Buffer,
                            mergedWithin gap: Int = 0) -> [Band] {
        var bands: [Band] = []
        var start: Int?

        for y in 0..<buffer.height {
            let tinted = (0..<buffer.width).contains { x in
                let offset = (y * buffer.width + x) * 4
                let red = Int(buffer.bytes[offset])
                let green = Int(buffer.bytes[offset + 1])
                let blue = Int(buffer.bytes[offset + 2])

                return blue > 150 && red < 120 && blue - green > 60
            }

            if tinted, start == nil { start = y }
            if !tinted, let from = start {
                bands.append(Band(top: from, bottom: y - 1))
                start = nil
            }
        }
        if let from = start { bands.append(Band(top: from, bottom: buffer.height - 1)) }

        guard gap > 0 else { return bands }

        return bands.reduce(into: [Band]()) { merged, band in
            if let last = merged.last, band.top - last.bottom <= gap {
                merged[merged.count - 1] = Band(top: last.top, bottom: band.bottom)
            } else {
                merged.append(band)
            }
        }
    }

    /// Anything that is not the background colour of the top-left corner.
    private static func isInk(_ buffer: ImageComparator.Buffer,
                              x: Int, y: Int,
                              background: (Int, Int, Int)) -> Bool {
        let offset = (y * buffer.width + x) * 4

        return abs(Int(buffer.bytes[offset]) - background.0) > 16
            || abs(Int(buffer.bytes[offset + 1]) - background.1) > 16
            || abs(Int(buffer.bytes[offset + 2]) - background.2) > 16
    }

    /// Topmost row where two renders differ by more than antialiasing; the
    /// threshold skips the few dozen pixels of drift a render carries anyway.
    static func firstDifferingRow(_ left: ImageComparator.Buffer,
                                  _ right: ImageComparator.Buffer,
                                  threshold: Int = 24) -> Int? {
        guard left.width == right.width, left.height == right.height else { return nil }

        return left.bytes.withUnsafeBufferPointer { l in
            right.bytes.withUnsafeBufferPointer { r in
                for y in 0..<left.height {
                    for x in 0..<left.width {
                        let offset = (y * left.width + x) * 4
                        for channel in 0..<3
                        where abs(Int(l[offset + channel]) - Int(r[offset + channel]))
                            > threshold {
                            return y
                        }
                    }
                }
                return nil
            }
        }
    }

    /// The today circle is the only large block of solid red the grid draws.
    static func redPixelsPerHalf(_ buffer: ImageComparator.Buffer)
    -> (leading: Int, trailing: Int) {
        var leading = 0
        var trailing = 0
        let middle = buffer.width / 2

        buffer.bytes.withUnsafeBufferPointer { bytes in
            for y in 0..<buffer.height {
                for x in 0..<buffer.width {
                    let offset = (y * buffer.width + x) * 4
                    guard bytes[offset] > 200, bytes[offset + 1] < 100,
                          bytes[offset + 2] < 100
                    else { continue }

                    if x < middle { leading += 1 } else { trailing += 1 }
                }
            }
        }

        return (leading, trailing)
    }
}
