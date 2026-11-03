import WidgetKit
import SwiftUI
import LeapCore

@main
struct LeapWidgetBundle: WidgetBundle {
    init() {
        // A build that has just replaced another leaves the host holding render
        // archives made from the old one, some of them written mid-swap and
        // covering only one appearance. Asking once, here, replaces them right
        // after the update instead of days later - see `BuildMarker`.
        guard BuildMarker().advance(to: BuildMarker.build(of: .main)) else { return }

        WidgetCenter.shared.reloadAllTimelines()
    }

    var body: some Widget {
        CalendarWidget()
        SmallCalendarWidget()
    }
}
