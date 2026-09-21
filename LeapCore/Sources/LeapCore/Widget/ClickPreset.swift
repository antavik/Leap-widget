import Foundation

public enum ClickPreset: String, CaseIterable, Sendable {
    case appleCalendar, fantastical, googleCalendar

    public var url: String {
        switch self {
        case .appleCalendar: "ical://"
        case .fantastical: "x-fantastical3://"
        case .googleCalendar: "https://calendar.google.com/"
        }
    }
}
