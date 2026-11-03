import SwiftUI
import LeapCore

struct CalendarWidgetView: View {
    let entry: CalendarEntry

    var body: some View {
        WidgetClickSurface(action: entry.model.clickAction) {
            CalendarSurface(models: entry.model.models, yearLabel: entry.model.yearLabel)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }
}
