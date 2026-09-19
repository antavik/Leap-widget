import Testing
import SwiftUI
@testable import LeapCore

/// Renders the composition the widget ships.
///
/// `containerBackground` is a no-op under `ImageRenderer`, so the harness
/// stands in with `.background` applied **after** `.frame`. The other order
/// leaves a transparent margin, and only on some fixtures — which is why the
/// opacity invariant runs on every case, not a representative one.
@MainActor
enum RenderHarness {
    static let scale: CGFloat = 2

    /// macOS's *default* accent, `#007AFF`. Unpinned, `.tint` resolves to the
    /// machine's System Settings accent and every onboarding golden fails on a
    /// runner that picked pink. Measured, not guessed: `Color.blue` is not the
    /// same — SwiftUI darkens it to `#0A84FF` in dark mode.
    static let accent = Color(.sRGB, red: 0, green: 0.478431, blue: 1, opacity: 1)

    /// The first render in a process differs by ±1 on ~0.07 % of pixels while
    /// font and colour caches warm up. A lazy static runs once, whoever gets
    /// there first — unlike a per-suite `init`, unordered across suites.
    static let warmedUp: Void = {
        _ = render(Text(verbatim: "warm-up").padding(),
                   size: WidgetGeometry.small.tile,
                   scheme: .light,
                   layoutDirection: .leftToRight)
    }()

    static func render(_ view: some View,
                       size: CGSize,
                       scheme: ColorScheme,
                       layoutDirection: LayoutDirection) -> CGImage? {
        let composed = view
            .frame(width: size.width, height: size.height)
            .background(.background)
            .tint(accent)
            .environment(\.colorScheme, scheme)
            .environment(\.layoutDirection, layoutDirection)

        let renderer = ImageRenderer(content: composed)
        renderer.scale = scale

        return renderer.cgImage
    }

    /// Height follows the content: the onboarding window is free in height.
    static func renderFlexibleHeight(_ view: some View,
                                     width: CGFloat,
                                     scheme: ColorScheme,
                                     layoutDirection: LayoutDirection) -> CGImage? {
        let composed = view
            .frame(width: width)
            .background(.background)
            .tint(accent)
            .environment(\.colorScheme, scheme)
            .environment(\.layoutDirection, layoutDirection)

        let renderer = ImageRenderer(content: composed)
        renderer.scale = scale

        return renderer.cgImage
    }

    /// Measured without a proposed frame — what the L2 clipping invariant
    /// compares against a tile's content box.
    static func intrinsicSize(_ view: some View, scheme: ColorScheme) -> CGSize? {
        let renderer = ImageRenderer(content: view.tint(accent)
            .environment(\.colorScheme, scheme))
        renderer.scale = 1

        return renderer.nsImage?.size
    }
}

/// Warms up before the first test of a rendering suite, without relying on
/// suite ordering.
struct WarmRenderer: SuiteTrait, TestTrait, TestScoping {
    func provideScope(for test: Test,
                      testCase: Test.Case?,
                      performing body: () async throws -> Void) async throws {
        await MainActor.run { _ = RenderHarness.warmedUp }
        try await body()
    }
}

extension Trait where Self == WarmRenderer {
    static var warmRenderer: Self { WarmRenderer() }
}
