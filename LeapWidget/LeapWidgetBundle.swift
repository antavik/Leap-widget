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
        guard BuildMarker().advance(to: Self.build) else { return }

        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Marketing version and build number: either one moving means the
    /// extension is not the one the host archived.
    private static var build: String {
        let info = Bundle.main.infoDictionary
        let marketing = info?["CFBundleShortVersionString"] as? String ?? "?"
        let number = info?["CFBundleVersion"] as? String ?? "?"

        return "\(marketing) (\(number))"
    }

    var body: some Widget {
        CalendarWidget()
        SmallCalendarWidget()
    }
}
