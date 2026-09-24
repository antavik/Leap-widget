import Testing
import SwiftUI
@testable import LeapCore

/// The `…Opacity` functions are the only way the increased-contrast branches
/// can be checked: no in-process render reaches them. The colours themselves
/// are not asserted – they derive from these opacities rather than repeating
/// the condition.
///
/// `monthNumberBaseline` is deliberately absent: restating its formula would
/// be a change detector with no independent truth.
/// `LayoutInvariantTests.theMonthNumberIsCapAlignedWithTheTitle` measures it.
@Suite("Theme")
struct ThemeTests {
    @Test(arguments: [(ColorScheme.light, ColorSchemeContrast.standard, 0.55),
                      (.light, .increased, 1.0),
                      (.dark, .standard, 1.0),
                      (.dark, .increased, 1.0)])
    func monthNumberTintFollowsSchemeAndContrast(scheme: ColorScheme,
                                                 contrast: ColorSchemeContrast,
                                                 opacity: Double) {
        #expect(Theme.monthNumberTintOpacity(colorScheme: scheme,
                                             contrast: contrast) == opacity)
    }

    @Test(arguments: [(ColorSchemeContrast.standard, 0.7), (.increased, 1.0)])
    func secondaryTextFollowsContrast(contrast: ColorSchemeContrast, opacity: Double) {
        #expect(Theme.secondaryTextOpacity(contrast: contrast) == opacity)
    }

    /// The L2 invariant measures `weekNumberColumnWidth + 7` off a render, so
    /// the constant itself has to be pinned somewhere.
    @Test(arguments: [(Theme.small, CGFloat(14)), (Theme.medium, CGFloat(12))])
    func weekNumberColumnWidthIsPinned(metrics: Theme.Metrics, width: CGFloat) {
        #expect(metrics.weekNumberColumnWidth == width)
    }
}
