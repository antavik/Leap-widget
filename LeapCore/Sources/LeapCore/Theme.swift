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
        let yearLabelTrailingInset: CGFloat

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
                               yearLabelTrailingInset: 6)

    static func monthNumberTintOpacity(colorScheme: ColorScheme,
                                       contrast: ColorSchemeContrast) -> Double {
        colorScheme == .dark || contrast == .increased ? 1 : 0.55
    }

    static func monthNumberTint(colorScheme: ColorScheme,
                                contrast: ColorSchemeContrast) -> AnyShapeStyle {
        AnyShapeStyle(.red.opacity(monthNumberTintOpacity(colorScheme: colorScheme,
                                                          contrast: contrast)))
    }

    static let medium = Metrics(title: 11, monthNumber: 8.5,
                                header: 9, day: 10,
                                weekNumber: 8, weekNumberColumnWidth: 12,
                                todayCircle: 18, rowHeight: 14, rowSpacing: 2,
                                yearLabelTrailingInset: 7)
}
