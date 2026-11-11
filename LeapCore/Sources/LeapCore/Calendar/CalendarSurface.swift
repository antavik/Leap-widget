import SwiftUI

public struct CalendarSurface: View {
    private let models: [MonthModel]
    private let yearLabels: [YearLabel?]

    public init(models: [MonthModel], yearLabels: [YearLabel?]) {
        self.models = models
        self.yearLabels = yearLabels
    }

    public var body: some View {
        MultiMonthView(models: models, yearLabels: yearLabels)
            .padding(WidgetGeometry.contentPadding)
    }
}
