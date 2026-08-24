import SwiftUI

/// Type and shape metrics for the month grid. Colors are never stored
/// here — views use semantic styles only.
public enum Theme {
    public struct Metrics: Equatable, Sendable {
        public let title: CGFloat
        public let header: CGFloat
        public let day: CGFloat
        public let weekNumber: CGFloat
        public let weekNumberColumnWidth: CGFloat
        public let todayCircle: CGFloat
        public let rowHeight: CGFloat
        public let rowSpacing: CGFloat
        public let titleLeadingInset: CGFloat

        public init(title: CGFloat,
                    header: CGFloat,
                    day: CGFloat,
                    weekNumber: CGFloat,
                    weekNumberColumnWidth: CGFloat,
                    todayCircle: CGFloat,
                    rowHeight: CGFloat,
                    rowSpacing: CGFloat,
                    titleLeadingInset: CGFloat) {
            self.title = title
            self.header = header
            self.day = day
            self.weekNumber = weekNumber
            self.weekNumberColumnWidth = weekNumberColumnWidth
            self.todayCircle = todayCircle
            self.rowHeight = rowHeight
            self.rowSpacing = rowSpacing
            self.titleLeadingInset = titleLeadingInset
        }
    }

    public static let single = Metrics(title: 13, header: 11, day: 12,
                                       weekNumber: 9, weekNumberColumnWidth: 14,
                                       todayCircle: 21, rowHeight: 16, rowSpacing: 2,
                                       titleLeadingInset: 6)

    public static let compact = Metrics(title: 11, header: 9, day: 10,
                                        weekNumber: 8, weekNumberColumnWidth: 12,
                                        todayCircle: 18, rowHeight: 14, rowSpacing: 2,
                                        titleLeadingInset: 7)
}
