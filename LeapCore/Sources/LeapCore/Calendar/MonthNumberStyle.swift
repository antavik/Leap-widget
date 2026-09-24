import Foundation

public enum MonthNumberStyle: String, CaseIterable, Sendable {
    case arabic
    case roman

    private static let romanLabels = ["I", "II", "III", "IV", "V", "VI",
                                                "VII", "VIII", "IX", "X", "XI", "XII"]

    public func label(forMonth month: Int) -> String? {
        switch self {
        case .arabic:
            return month > 0 ? String(month) : nil
        case .roman:
            return (1...12).contains(month) ? Self.romanLabels[month - 1] : nil
        }
    }
}
