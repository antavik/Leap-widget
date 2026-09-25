import Testing
import LeapCore

/// Intent → `CalendarSettings`, the one link `LeapCore` cannot run.
/// Unqualified `Companion`, `ClickAction`, … are the widget's `AppEnum`s.
@Suite("Widget intents")
struct ConfigurationIntentTests {

    // MARK: - Defaults

    /// New widgets and the gallery placeholder start here.
    @Test func freshIntentsCarryTheCoreDefaults() {
        #expect(CalendarConfigIntent().settings == CalendarSettings(monthOffsets: [0, 1]))
        #expect(SmallCalendarConfigIntent().settings == CalendarSettings(monthOffsets: [0]))
    }

    // MARK: - One parameter at a time

    /// One parameter at a time: a swapped argument moves the wrong field.
    @Test func everyTwoMonthParameterMovesOnlyItsOwnField() {
        func edited(_ edit: (CalendarConfigIntent) -> Void) -> CalendarSettings {
            let intent = CalendarConfigIntent()
            edit(intent)
            return intent.settings
        }
        let months = [0, 1]

        #expect(edited { $0.companion = .previous } == CalendarSettings(monthOffsets: [-1, 0]))
        #expect(edited { $0.firstWeekday = .monday }
                == CalendarSettings(monthOffsets: months, firstWeekday: .monday))
        #expect(edited { $0.firstWeekday = .sunday }
                == CalendarSettings(monthOffsets: months, firstWeekday: .sunday))
        #expect(edited { $0.showWeekNumbers = true }
                == CalendarSettings(monthOffsets: months, showWeekNumbers: true))
        #expect(edited { $0.showOutsideDays = false }
                == CalendarSettings(monthOffsets: months, showOutsideDays: false))
        #expect(edited { $0.showYear = false }
                == CalendarSettings(monthOffsets: months, showYear: false))
        #expect(edited { $0.monthNumber = .arabic }
                == CalendarSettings(monthOffsets: months, monthNumber: .arabic))
        #expect(edited { $0.monthNumber = .roman }
                == CalendarSettings(monthOffsets: months, monthNumber: .roman))
        for action in ClickAction.allCases {
            #expect(edited { $0.clickAction = action }
                    == CalendarSettings(monthOffsets: months, clickAction: action.core),
                    "\(action)")
        }
    }

    @Test func everyOneMonthParameterMovesOnlyItsOwnField() {
        func edited(_ edit: (SmallCalendarConfigIntent) -> Void) -> CalendarSettings {
            let intent = SmallCalendarConfigIntent()
            edit(intent)
            return intent.settings
        }
        let month = [0]

        #expect(edited { $0.month = .next } == CalendarSettings(monthOffsets: [1]))
        #expect(edited { $0.month = .previous } == CalendarSettings(monthOffsets: [-1]))
        #expect(edited { $0.firstWeekday = .monday }
                == CalendarSettings(monthOffsets: month, firstWeekday: .monday))
        #expect(edited { $0.firstWeekday = .sunday }
                == CalendarSettings(monthOffsets: month, firstWeekday: .sunday))
        #expect(edited { $0.showWeekNumbers = true }
                == CalendarSettings(monthOffsets: month, showWeekNumbers: true))
        #expect(edited { $0.showOutsideDays = false }
                == CalendarSettings(monthOffsets: month, showOutsideDays: false))
        #expect(edited { $0.showYear = false }
                == CalendarSettings(monthOffsets: month, showYear: false))
        #expect(edited { $0.monthNumber = .arabic }
                == CalendarSettings(monthOffsets: month, monthNumber: .arabic))
        #expect(edited { $0.monthNumber = .roman }
                == CalendarSettings(monthOffsets: month, monthNumber: .roman))
        for action in ClickAction.allCases {
            #expect(edited { $0.clickAction = action }
                    == CalendarSettings(monthOffsets: month, clickAction: action.core),
                    "\(action)")
        }
    }

    // MARK: - Bridging

    /// `core` falls back to a default, so a renamed case would pass silently.
    @Test func everyWidgetCaseBridgesToTheCoreCaseOfTheSameName() {
        for option in Companion.allCases { #expect(option.core.rawValue == option.rawValue) }
        for option in DisplayedMonth.allCases { #expect(option.core.rawValue == option.rawValue) }
        for option in FirstWeekday.allCases { #expect(option.core.rawValue == option.rawValue) }
        for option in MonthNumberDisplay.allCases {
            #expect(option.core.rawValue == option.rawValue)
        }
        for option in ClickAction.allCases { #expect(option.core.rawValue == option.rawValue) }
    }
}
