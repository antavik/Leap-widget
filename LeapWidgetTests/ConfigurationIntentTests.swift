import Testing
import LeapCore

/// Intent → `CalendarSettings`, the one link `LeapCore` cannot run.
@Suite("Widget intents")
struct ConfigurationIntentTests {

    // MARK: - Defaults

    /// New widgets and the gallery placeholder start here.
    @Test func freshIntentsCarryTheCoreDefaults() {
        #expect(CalendarConfigIntent().settings == CalendarSettings(monthOffsets: [0, 1]))
        #expect(SmallCalendarConfigIntent().settings == CalendarSettings(monthOffsets: [0]))
    }

    // MARK: - One parameter at a time

    /// Each two-month parameter moves only its own `CalendarSettings` field;
    /// a swapped argument in `settings` moves the wrong one.
    @Test func everyTwoMonthParameterMovesOnlyItsOwnField() {
        func settings(editing edit: (CalendarConfigIntent) -> Void) -> CalendarSettings {
            let intent = CalendarConfigIntent()
            edit(intent)
            return intent.settings
        }
        let months = [0, 1]

        #expect(settings { $0.companion = Companion.previous.rawValue }
                == CalendarSettings(monthOffsets: [-1, 0]))
        #expect(settings { $0.firstWeekday = FirstWeekday.monday.rawValue }
                == CalendarSettings(monthOffsets: months, firstWeekday: .monday))
        #expect(settings { $0.firstWeekday = FirstWeekday.sunday.rawValue }
                == CalendarSettings(monthOffsets: months, firstWeekday: .sunday))
        #expect(settings { $0.showWeekNumbers = true }
                == CalendarSettings(monthOffsets: months, showWeekNumbers: true))
        #expect(settings { $0.showOutsideDays = false }
                == CalendarSettings(monthOffsets: months, showOutsideDays: false))
        #expect(settings { $0.showYear = false }
                == CalendarSettings(monthOffsets: months, showYear: false))
        #expect(settings { $0.monthNumber = MonthNumberDisplay.arabic.rawValue }
                == CalendarSettings(monthOffsets: months, monthNumber: .arabic))
        #expect(settings { $0.monthNumber = MonthNumberDisplay.roman.rawValue }
                == CalendarSettings(monthOffsets: months, monthNumber: .roman))
        for action in ClickAction.allCases {
            #expect(settings { $0.clickAction = action.rawValue }
                    == CalendarSettings(monthOffsets: months, clickAction: action),
                    "\(action)")
        }
    }

    /// Each one-month parameter moves only its own `CalendarSettings` field.
    @Test func everyOneMonthParameterMovesOnlyItsOwnField() {
        func settings(editing edit: (SmallCalendarConfigIntent) -> Void) -> CalendarSettings {
            let intent = SmallCalendarConfigIntent()
            edit(intent)
            return intent.settings
        }
        let month = [0]

        #expect(settings { $0.month = DisplayedMonth.next.rawValue }
                == CalendarSettings(monthOffsets: [1]))
        #expect(settings { $0.month = DisplayedMonth.previous.rawValue }
                == CalendarSettings(monthOffsets: [-1]))
        #expect(settings { $0.firstWeekday = FirstWeekday.monday.rawValue }
                == CalendarSettings(monthOffsets: month, firstWeekday: .monday))
        #expect(settings { $0.firstWeekday = FirstWeekday.sunday.rawValue }
                == CalendarSettings(monthOffsets: month, firstWeekday: .sunday))
        #expect(settings { $0.showWeekNumbers = true }
                == CalendarSettings(monthOffsets: month, showWeekNumbers: true))
        #expect(settings { $0.showOutsideDays = false }
                == CalendarSettings(monthOffsets: month, showOutsideDays: false))
        #expect(settings { $0.showYear = false }
                == CalendarSettings(monthOffsets: month, showYear: false))
        #expect(settings { $0.monthNumber = MonthNumberDisplay.arabic.rawValue }
                == CalendarSettings(monthOffsets: month, monthNumber: .arabic))
        #expect(settings { $0.monthNumber = MonthNumberDisplay.roman.rawValue }
                == CalendarSettings(monthOffsets: month, monthNumber: .roman))
        for action in ClickAction.allCases {
            #expect(settings { $0.clickAction = action.rawValue }
                    == CalendarSettings(monthOffsets: month, clickAction: action),
                    "\(action)")
        }
    }

    // MARK: - Saved choices

    /// The picker offers every case by its user-facing value and starts on
    /// the fallback's value; a missing or unknown saved value reads back as
    /// the fallback, and legacy raw values still decode to their case.
    @Test func everyPickerOffersDisplayValuesAndFallsBack() async throws {
        func check<Provider: WidgetOptionProvider>(
            _ provider: Provider,
            _ displayValues: [String]
        ) async throws where Provider.Option: Equatable {
            typealias Option = Provider.Option

            #expect(try await provider.results().items == displayValues)
            #expect(await provider.defaultResult() == displayValues.first)
            for (option, displayValue) in zip(Option.allCases, displayValues) {
                #expect(Option(saved: displayValue) == option,
                        "decodes new value \(displayValue)")
                #expect(Option(saved: option.rawValue) == option,
                        "decodes legacy value \(option.rawValue)")
            }
            #expect(Option(saved: nil) == Option.fallback)
            #expect(Option(saved: "unknown") == Option.fallback)
        }

        try await check(CompanionOptions(), ["Next", "Previous"])
        try await check(DisplayedMonthOptions(), ["Current", "Next", "Previous"])
        try await check(FirstWeekdayOptions(), ["System Default", "Monday", "Sunday"])
        try await check(MonthNumberDisplayOptions(), ["Off", "Number (6)", "Roman (VI)"])
        try await check(ClickActionOptions(),
                        ["Default Calendar", "Fantastical", "Google Calendar", "Nothing"])
    }
}
