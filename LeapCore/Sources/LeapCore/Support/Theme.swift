import SwiftUI

enum Theme {
    struct Metrics: Equatable, Sendable {
        let title: CGFloat
        let monthNumber: CGFloat
        let header: CGFloat
        let day: CGFloat
        let weekNumber: CGFloat
        let weekNumberColumnWidth: CGFloat
        let todayCircle: CGFloat
        let rowHeight: CGFloat
        let rowSpacing: CGFloat
        let titleSpacing: CGFloat
        let monthSpacing: CGFloat

        /// Glyph-bbox top as a fraction of point size, measured with
        /// `CTFontGetBoundingRectsForGlyphs`. Caps and lining digits share it.
        private static let capTopRatio: CGFloat = 0.7222

        /// The raised run's raster origin snaps to a device pixel, landing the
        /// number a pixel low. Measured at 1x–3x.
        private static let pixelSnapLift: CGFloat = 0.3

        var monthNumberBaseline: CGFloat {
            (title - monthNumber) * Self.capTopRatio + Self.pixelSnapLift
        }
    }

    /// One month, `.systemSmall`.
    static let small = Metrics(title: 11, monthNumber: 8.5,
                               header: 9, day: 10,
                               weekNumber: 8, weekNumberColumnWidth: 14,
                               todayCircle: 18, rowHeight: 16, rowSpacing: 2,
                               titleSpacing: 4, monthSpacing: 10)

    /// Stronger than `.secondary` (≈0.5 on macOS), which falls short of
    /// 4.5:1 contrast for `.callout` text.
    static func secondaryTextOpacity(contrast: ColorSchemeContrast) -> Double {
        contrast == .increased ? 1 : 0.7
    }

    static func secondaryText(contrast: ColorSchemeContrast) -> Color {
        .primary.opacity(secondaryTextOpacity(contrast: contrast))
    }

    static func monthNumberTintOpacity(colorScheme: ColorScheme,
                                       contrast: ColorSchemeContrast) -> Double {
        colorScheme == .dark || contrast == .increased ? 1 : 0.55
    }

    static func monthNumberTint(colorScheme: ColorScheme,
                                contrast: ColorSchemeContrast) -> Color {
        .red.opacity(monthNumberTintOpacity(colorScheme: colorScheme, contrast: contrast))
    }

    enum Onboarding {
        static let padding: CGFloat = 24
        static let sectionSpacing: CGFloat = 20
        static let headerSpacing: CGFloat = 4
        static let footerSpacing: CGFloat = 6
        static let footerDividerGap: CGFloat = 8
        static let linkSpacing: CGFloat = 14
    }

    static let medium = Metrics(title: 11, monthNumber: 8.5,
                                header: 9, day: 10,
                                weekNumber: 8, weekNumberColumnWidth: 12,
                                todayCircle: 18, rowHeight: 14, rowSpacing: 2,
                                titleSpacing: 4, monthSpacing: 10)
}
