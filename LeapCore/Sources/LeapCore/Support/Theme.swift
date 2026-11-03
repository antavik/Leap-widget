import SwiftUI

enum Theme {
    struct Metrics: Equatable, Sendable {
        let title: Double
        let monthNumber: Double
        let header: Double
        let day: Double
        let weekNumber: Double
        let weekNumberColumnWidth: Double
        let todayCircle: Double
        let rowHeight: Double
        let rowSpacing: Double
        let titleSpacing: Double
        let monthSpacing: Double

        /// Glyph-bbox top as a fraction of point size, measured with
        /// `CTFontGetBoundingRectsForGlyphs`. Caps and lining digits share it.
        private static let capTopRatio = 0.7222

        /// The raised run's raster origin snaps to a device pixel, landing the
        /// number a pixel low. Measured at 1x–3x.
        private static let pixelSnapLift = 0.3

        var monthNumberBaseline: Double {
            (title - monthNumber) * Self.capTopRatio + Self.pixelSnapLift
        }
    }

    /// One month, `.systemSmall`.
    static let small = Metrics(title: 11, monthNumber: 8.5,
                               header: 9, day: 10,
                               weekNumber: 8, weekNumberColumnWidth: 14,
                               todayCircle: 18, rowHeight: 16, rowSpacing: 2,
                               titleSpacing: 4, monthSpacing: 10)

    static let medium = Metrics(title: 11, monthNumber: 8.5,
                                header: 9, day: 10,
                                weekNumber: 8, weekNumberColumnWidth: 12,
                                todayCircle: 18, rowHeight: 14, rowSpacing: 2,
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
        static let padding: Double = 24
        static let sectionSpacing: Double = 20
        static let headerSpacing: Double = 4
        static let footerSpacing: Double = 6
        static let footerDividerGap: Double = 8
        static let linkSpacing: Double = 14
        static let stepSpacing: Double = 12
        static let stepTextSpacing: Double = 2
        static let stepIconWidth: Double = 28
    }
}
