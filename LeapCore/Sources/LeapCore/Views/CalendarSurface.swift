import SwiftUI

public struct CalendarSurface: View {
    private let models: [MonthModel]
    private let yearLabel: String?

    public init(models: [MonthModel], yearLabel: String?) {
        self.models = models
        self.yearLabel = yearLabel
    }

    public var body: some View {
        MultiMonthView(models: models, yearLabel: yearLabel)
            .padding(WidgetGeometry.contentPadding)
    }
}
