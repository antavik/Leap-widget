import Testing
import SwiftUI
import Foundation
@testable import LeapCore

/// L2 – the year label's colour, per month (Linear A-79).
///
/// December's two-month row spans a year boundary. Each month carries the
/// label of its own year, and only the current month's label is red; the
/// other renders like a week number (`.secondary`). Exact shades belong to the
/// goldens; this pins the colour *class* of each label.
@Suite("Year label colours", .tags(.layout), .serialized, .warmRenderer)
@MainActor
struct YearLabelColorTests {
    private struct Pixel {
        let y: Int
        let r: Int
        let g: Int
        let b: Int

        var isRed: Bool { r > 200 && g < 100 && b < 100 }
        /// Grey ink: its channels barely differ. Anti-aliased grey over white stays grey.
        var isGrey: Bool { max(r, g, b) - min(r, g, b) <= 24 }
    }

    private func render(showYear: Bool) throws
    -> (entry: CalendarEntryModel, buffer: ImageComparator.Buffer) {
        let entry = try GoldenCase.entry(
            settings: CalendarSettings(monthOffsets: Companion.next.monthOffsets,
                                       showYear: showYear),
            calendar: Fixtures.mondayFirst,
            reference: Fixtures.december)
        let image = try #require(RenderHarness.render(
            CalendarSurface(models: entry.models, yearLabels: entry.yearLabels),
            size: WidgetGeometry.medium.tileSize, scheme: .light, layoutDirection: .leftToRight))

        return (entry, try #require(ImageComparator.buffer(of: image)))
    }

    @Test func spanningDecemberRowLabelsBothMonthsInTheirOwnColors() throws {
        let on = try render(showYear: true)
        let off = try render(showYear: false)
        #expect(on.entry.models.map(\.title) == ["DECEMBER", "JANUARY"])

        // The titles are red too, so each label is isolated as the pixels that
        // change when the year is turned off.
        let middle = on.buffer.width / 2
        let leading = Self.changedPixels(from: off.buffer, to: on.buffer, columns: 0..<middle)
        let trailing = Self.changedPixels(from: off.buffer, to: on.buffer,
                                          columns: middle..<on.buffer.width)

        // Both months drew a label, in the title band only.
        let title = Self.titleRows(of: off.buffer)
        #expect(!leading.isEmpty, "the leading month (December) drew no year label")
        #expect(!trailing.isEmpty, "the trailing month (January) drew no year label")
        for (name, label) in [("leading", leading), ("trailing", trailing)] {
            #expect(label.allSatisfy { title.contains($0.y) },
                    "\(name) label outside the title rows \(title)")
        }

        // Colour follows the month, not the position: December (offset 0, the
        // leading half) is current → red; January (the trailing half) is the
        // other year → grey.
        #expect(leading.filter(\.isRed).count > 10,
                "the current month's label lost the accent colour")
        #expect(trailing.filter(\.isRed).isEmpty,
                "the other year's label is red: \(trailing.filter(\.isRed).count) px")
        #expect(trailing.filter(\.isGrey).count > 10, "the other year's label is not grey")
    }

    // MARK: - Measuring

    /// The first run of inked rows: the month titles, before the blank gap
    /// above the weekday headers.
    private static func titleRows(of buffer: ImageComparator.Buffer) -> ClosedRange<Int> {
        let background = (Int(buffer.bytes[0]), Int(buffer.bytes[1]), Int(buffer.bytes[2]))
        let inked = { (y: Int) in
            (0..<buffer.width).contains { x in
                let offset = (y * buffer.width + x) * 4

                return abs(Int(buffer.bytes[offset]) - background.0) > 16
                    || abs(Int(buffer.bytes[offset + 1]) - background.1) > 16
                    || abs(Int(buffer.bytes[offset + 2]) - background.2) > 16
            }
        }

        guard let top = (0..<buffer.height).first(where: inked) else { return 0...0 }

        let bottom = (top..<buffer.height).first { !inked($0) } ?? buffer.height

        return top...(bottom - 1)
    }

    /// The pixels of `after` that differ from `before` beyond the comparator's
    /// own tolerance, within `columns`.
    private static func changedPixels(from before: ImageComparator.Buffer,
                                      to after: ImageComparator.Buffer,
                                      columns: Range<Int>) -> [Pixel] {
        precondition(before.width == after.width && before.height == after.height,
                     "renders of different sizes")

        var changed: [Pixel] = []
        for y in 0..<after.height {
            for x in columns {
                let offset = (y * after.width + x) * 4
                let differs = (0..<4).contains {
                    abs(Int(before.bytes[offset + $0]) - Int(after.bytes[offset + $0]))
                        > ImageComparator.channelTolerance
                }
                if differs {
                    changed.append(Pixel(y: y,
                                         r: Int(after.bytes[offset]),
                                         g: Int(after.bytes[offset + 1]),
                                         b: Int(after.bytes[offset + 2])))
                }
            }
        }

        return changed
    }
}
