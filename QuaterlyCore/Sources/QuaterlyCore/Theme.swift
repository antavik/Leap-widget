import SwiftUI

/// Type and shape metrics for the month grid (§4.4). Colors are never stored
/// here — views use semantic styles only (§4.5).
public enum Theme {
    public struct Metrics: Equatable, Sendable {
        public let title: CGFloat
        public let header: CGFloat
        public let day: CGFloat
        public let weekNumber: CGFloat
        public let weekNumberColumnWidth: CGFloat
        public let todayCircle: CGFloat
        public let rowSpacing: CGFloat

        public init(title: CGFloat,
                    header: CGFloat,
                    day: CGFloat,
                    weekNumber: CGFloat,
                    weekNumberColumnWidth: CGFloat,
                    todayCircle: CGFloat,
                    rowSpacing: CGFloat) {
            self.title = title
            self.header = header
            self.day = day
            self.weekNumber = weekNumber
            self.weekNumberColumnWidth = weekNumberColumnWidth
            self.todayCircle = todayCircle
            self.rowSpacing = rowSpacing
        }
    }

    /// Single-month scale — the reference-screenshot values (§4.4).
    public static let single = Metrics(title: 13, header: 11, day: 12,
                                       weekNumber: 9, weekNumberColumnWidth: 14,
                                       todayCircle: 17, rowSpacing: 2)

    /// One notch down for spans of two or more months (§4.4).
    public static let compact = Metrics(title: 11, header: 9, day: 10,
                                        weekNumber: 8, weekNumberColumnWidth: 12,
                                        todayCircle: 14, rowSpacing: 2)
}
