import WidgetKit
import SwiftUI

@main
struct LeapWidgetBundle: WidgetBundle {
    var body: some Widget {
        CalendarWidget()
        SmallCalendarWidget()
    }
}
