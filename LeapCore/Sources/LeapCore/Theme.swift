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

        init(title: CGFloat,
                    monthNumber: CGFloat,
                    header: CGFloat,
                    day: CGFloat,
                    weekNumber: CGFloat,
                    weekNumberColumnWidth: CGFloat,
                    todayCircle: CGFloat,
                    rowHeight: CGFloat,
                    rowSpacing: CGFloat,
                    yearLabelTrailingInset: CGFloat) {
            self.title = title
            self.monthNumber = monthNumber
            self.header = header
            self.day = day
            self.weekNumber = weekNumber
            self.weekNumberColumnWidth = weekNumberColumnWidth
            self.todayCircle = todayCircle
            self.rowHeight = rowHeight
            self.rowSpacing = rowSpacing
            self.yearLabelTrailingInset = yearLabelTrailingInset
        }

        /// Glyph-bbox top as a fraction of point size for the system face,
        /// measured with `CTFontGetBoundingRectsForGlyphs`. Caps and lining
        /// digits share it, so one ratio positions both runs.
        private static let capTopRatio: CGFloat = 0.7222

        /// The raised run's raster origin snaps to a device pixel, and that
        /// rounding lands the number a pixel below the title. Measured at
        /// 1x-3x, this lift puts both presets' cap tops on the title's row.
        private static let pixelSnapLift: CGFloat = 0.3

        /// Baseline lift that aligns the month number's cap top with the title's.
        var monthNumberBaseline: CGFloat {
            (title - monthNumber) * Self.capTopRatio + Self.pixelSnapLift
        }
    }

    /// One month, `.systemSmall`.
    static let small = Metrics(title: 13, monthNumber: 9.5,
                               header: 11, day: 12,
                               weekNumber: 9, weekNumberColumnWidth: 14,
                               todayCircle: 21, rowHeight: 16, rowSpacing: 2,
                               yearLabelTrailingInset: 6)

    /// Two months side by side, `.systemMedium`; everything shrinks to fit.
    static let medium = Metrics(title: 11, monthNumber: 8.5,
                                header: 9, day: 10,
                                weekNumber: 8, weekNumberColumnWidth: 12,
                                todayCircle: 18, rowHeight: 14, rowSpacing: 2,
                                yearLabelTrailingInset: 7)
}
