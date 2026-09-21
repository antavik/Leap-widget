import Testing
import SwiftUI
import Foundation
@testable import LeapCore

/// L3 – golden snapshots. A change detector, not a correctness oracle: a diff
/// means "look at this", and a human decides.
///
/// On by default, opted *out* with `LEAP_SKIP_SNAPSHOTS` – a net that needs a
/// remembered variable only catches regressions you already suspected.
@Suite("Snapshots",
       .tags(.golden),
       .serialized,
       .timeLimit(.minutes(1)),
       .warmRenderer,
       .disabled(if: GoldenStore.isSkipped, "opted out via LEAP_SKIP_SNAPSHOTS"),
       .disabled(if: !GoldenStore.isAvailable && !GoldenStore.isRecording,
                 GoldenStore.unavailableReason))
@MainActor
struct SnapshotTests {
    @Test(arguments: GoldenCase.all)
    func goldenMatches(_ golden: GoldenCase) throws {
        let rendered = try golden.render()

        // Every render, not only failures: the report folder is a visual
        // record of the UI at that commit.
        GoldenStore.writeScreenshot(rendered, id: golden.id)

        guard !GoldenStore.isRecording else {
            try record(rendered, golden: golden)
            return
        }

        try #require(GoldenStore.exists(id: golden.id),
                     """
                     no golden recorded for \(golden.id) – \
                     run `make snapshots-record`
                     """)

        let expected = try #require(ImageComparator.buffer(of: GoldenStore.read(id: golden.id)))
        let actual = try #require(ImageComparator.buffer(of: rendered))
        let difference = ImageComparator.compare(expected, actual)

        if difference.exceedsTolerance {
            try attachFailure(golden: golden, expected: expected, actual: actual,
                              rendered: rendered)
        }

        #expect(!difference.exceedsTolerance,
                "\(golden.id): \(difference.summary)")
    }

    /// Rewrites only the cases that moved, so the diff is exactly the set of
    /// images the author agreed to change.
    private func record(_ rendered: CGImage, golden: GoldenCase) throws {
        if GoldenStore.exists(id: golden.id),
           let stored = try? GoldenStore.read(id: golden.id),
           let expected = ImageComparator.buffer(of: stored),
           let actual = ImageComparator.buffer(of: rendered),
           !ImageComparator.compare(expected, actual).exceedsTolerance {
            return
        }

        try GoldenStore.write(rendered, id: golden.id)
    }

    /// Expected, actual and an amplified diff, as attachments and as files –
    /// the one filesystem write the fast loop is allowed, and only on failure.
    private func attachFailure(golden: GoldenCase,
                               expected: ImageComparator.Buffer,
                               actual: ImageComparator.Buffer,
                               rendered: CGImage) throws {
        let stored = try GoldenStore.read(id: golden.id)

        attach(stored, named: "\(golden.id)-expected.png")
        attach(rendered, named: "\(golden.id)-actual.png")

        GoldenStore.writeDiff(stored, named: "\(golden.id)-expected.png")
        GoldenStore.writeDiff(rendered, named: "\(golden.id)-actual.png")

        if let diff = ImageComparator.amplifiedDiff(expected: expected, actual: actual) {
            attach(diff, named: "\(golden.id)-diff.png")
            GoldenStore.writeDiff(diff, named: "\(golden.id)-diff.png")
        }
    }

    /// `CGImage` is not `Attachable`; its PNG bytes are.
    private func attach(_ image: CGImage, named name: String) {
        guard let data = ImageComparator.pngData(of: image) else { return }

        Attachment.record(data, named: name)
    }
}
