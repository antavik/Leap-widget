import SwiftUI
import LeapCore

struct CalendarWidgetView: View {
    let entry: CalendarEntry

    var body: some View {
        WidgetClickSurface(target: entry.clickTarget) {
            CalendarSurface(models: entry.models, yearLabel: entry.yearLabel)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }
}
