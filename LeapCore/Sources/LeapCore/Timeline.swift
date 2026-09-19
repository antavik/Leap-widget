import Foundation

public struct CalendarEntryModel: Equatable, Sendable {
    public let date: Date
    public let clickTarget: ClickPreset?
    public let models: [MonthModel]
    public let yearLabel: String?

    public init(date: Date,
                settings: CalendarSettings,
                builder: MonthModelBuilder) {
        let row = monthRow(containing: date,
                           offsets: settings.monthOffsets,
                           showYear: settings.showYear,
                           builder: builder)

        self.date = date
        self.clickTarget = settings.clickPreset
        self.models = row.models
        self.yearLabel = row.yearLabel
    }
}

public func calendarEntries(for settings: CalendarSettings,
                            now: Date,
                            calendar: Calendar) -> [CalendarEntryModel] {
    let builder = MonthModelBuilder(calendar: calendar,
                                    options: settings.monthOptions)

    return timelineDates(from: now, calendar: calendar).map {
        CalendarEntryModel(date: $0, settings: settings, builder: builder)
    }
}
