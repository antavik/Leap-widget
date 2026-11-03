import Foundation

public enum Constants {
    public enum Links {
        public static let donation = URL(string: "https://buymeacoffee.com/antavik")!
    }

    public enum Mail {
        public static let address = "antavik@pm.me"

        public enum Subject {
            public static let feedback = "Leap Widget feedback"
            public static let support = "Leap Widget support"
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
        public static let calendar = "com.antavik.leapwidget.calendar"
        public static let calendarSmall = "com.antavik.leapwidget.calendar.small"
    }

    public enum Defaults {
        public static let widgetBuild = "LeapWidgetBuild"
        public static let repairedBuild = "LeapRepairedBuild"
    }

    public enum Bundles {
        public static let appleCalendar = "com.apple.iCal"

        /// Release ID; Debug builds append `.debug`.
        public static let leap = "com.antavik.leapwidget"

        /// The running app's ID, suffix included. Meaningful in the app only.
        public static var current: String {
            Bundle.main.bundleIdentifier ?? leap
        }

        public static func widgetExtension(in app: URL) -> URL {
            app.appending(components: "Contents", "PlugIns", "LeapWidget.appex")
        }
    }
}
