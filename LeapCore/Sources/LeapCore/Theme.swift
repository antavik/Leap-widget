import SwiftUI

/// Type and shape metrics for the month grid. Colors are never stored
/// here — views use semantic styles only.
public enum Theme {
    public struct Metrics: Equatable, Sendable {
        public let title: CGFloat
        public let monthNumber: CGFloat
        public let header: CGFloat
        public let day: CGFloat
        public let weekNumber: CGFloat
        public let weekNumberColumnWidth: CGFloat
        public let todayCircle: CGFloat
        public let rowHeight: CGFloat
        public let rowSpacing: CGFloat
        public let titleLeadingInset: CGFloat

        public init(title: CGFloat,
                    monthNumber: CGFloat,
                    header: CGFloat,
                    day: CGFloat,
                    weekNumber: CGFloat,
                    weekNumberColumnWidth: CGFloat,
                    todayCircle: CGFloat,
                    rowHeight: CGFloat,
                    rowSpacing: CGFloat,
                    titleLeadingInset: CGFloat) {
            self.title = title
            self.monthNumber = monthNumber
            self.header = header
            self.day = day
            self.weekNumber = weekNumber
            self.weekNumberColumnWidth = weekNumberColumnWidth
            self.todayCircle = todayCircle
            self.rowHeight = rowHeight
            self.rowSpacing = rowSpacing
            self.titleLeadingInset = titleLeadingInset
        }

        /// Cap height as a fraction of point size for the system face; both
        /// the title and the month number are set in it, so the ratio cancels
        /// out of everything except this lift.
        private static let capHeightRatio: CGFloat = 0.7

        /// Baseline lift that puts the month number's cap on the title's cap,
        /// so the two share a top edge whatever the two sizes are.
        public var monthNumberBaseline: CGFloat {
            (title - monthNumber) * Self.capHeightRatio
        }
    }

    public static let single = Metrics(title: 13, monthNumber: 9,
                                       header: 11, day: 12,
                                       weekNumber: 9, weekNumberColumnWidth: 14,
                                       todayCircle: 21, rowHeight: 16, rowSpacing: 2,
                                       titleLeadingInset: 6)

    public static let compact = Metrics(title: 11, monthNumber: 8,
                                        header: 9, day: 10,
                                        weekNumber: 8, weekNumberColumnWidth: 12,
                                        todayCircle: 18, rowHeight: 14, rowSpacing: 2,
                                        titleLeadingInset: 7)
}
