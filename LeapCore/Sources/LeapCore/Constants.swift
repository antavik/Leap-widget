import Foundation

public enum Constants {
    public enum Links {
        public static let donation = URL(string: "https://buymeacoffee.com/antavik")!
    }

    public enum Mail {
        public static let address = "antavik@pm.me"

        public enum Subject {
            public static let feedback = "Leap feedback"
            public static let support = "Leap support"
        }

        public static let feedback = url(subject: Subject.feedback)
        public static let support = url(subject: Subject.support)

        public static func url(subject: String, address: String = address) -> URL {
            var components = URLComponents()
            components.scheme = "mailto"
            components.path = address
            components.queryItems = [URLQueryItem(name: "subject", value: subject)]
            return components.url ?? URL(string: "mailto:\(address)")!
        }
    }

    public enum Widgets {
        public static let calendar = "com.antavik.leap.calendar"
        public static let calendarSmall = "com.antavik.leap.calendar.small"
    }

    public enum Bundles {
        public static let appleCalendar = "com.apple.iCal"
    }
}
