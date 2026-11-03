import Foundation

public struct Day: Equatable, Sendable {
    public let number: Int
    public let isToday: Bool
    public let isOutsideMonth: Bool

    init(number: Int, isToday: Bool, isOutsideMonth: Bool = false) {
        self.number = number
        self.isToday = isToday
        self.isOutsideMonth = isOutsideMonth
    }
}
