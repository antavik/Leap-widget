# Quaterly — Implementation TODO

Derived from DESIGN.md v2.4. Ordered by milestone (§8); every task references the design
section that specifies it. Check items off as they land.

---

## M0 — Project scaffold

- [x] Create `Quaterly.xcodeproj` with two targets (§4.1):
  - [x] `Quaterly` — host app, SwiftUI, macOS 14 deployment target
  - [x] `QuaterlyWidget` — widget extension, macOS 14 deployment target
- [x] Create local Swift package `QuaterlyCore`, link into both targets (§4.1)
- [x] `Package.swift` declares `dependencies: []` — add CI check that fails the build if
  a dependency ever appears (G11, §6) — `Scripts/check-no-dependencies.sh` + workflow
- [x] Set bundle IDs: `com.antavik.quaterly` / `com.antavik.quaterly.widget` (§4.1)
- [x] Enable App Sandbox + Hardened Runtime on both targets (§6)
- [x] Add App Group `<TEAMID>.com.antavik.quaterly` to both targets — Team-ID-prefixed
  form via `$(TeamIdentifierPrefix)`, **not** `group.*` (§4.1). ⚠️ Set the real team +
  update `AppGroup.identifier` literal before signed distribution
- [x] Host app: `LSUIElement` / activation policy `.accessory` (§4.1)
- [x] Host app: declare `quaterly` URL scheme in `CFBundleURLTypes` (§4.9)
- [x] Commit DESIGN.md + scaffold as initial commit

## M1 — QuaterlyCore: models, math, grid view (§8 M1, 2–3 d)

### Models & math (§4.3)

- [x] `Day` struct: `number`, `isToday`, `isWeekend`
- [x] `MonthModel` struct: `title`, `year`, `weekdayHeaders: [String]`,
  `weeks: [[Day?]]`, `weekNumbers: [Int]?`
- [x] `MonthOptions` struct: `firstWeekday: Int?` (1 = Sunday … 7 = Saturday),
  `showWeekNumbers: Bool`
- [x] `monthModel(containing:offset:calendar:today:options:)` pure function:
  - [x] Effective calendar: copy input calendar, override `firstWeekday` when option
    set — layout, header rotation, and week numbering all derive from it (§4.3)
  - [x] Month title: uppercased standalone month symbol
  - [x] Weekday headers: very-short standalone symbols rotated by effective first
    weekday
  - [x] Weeks: 7-column rows, `nil` for leading/trailing blanks — no adjacent-month
    days (§4.3)
  - [x] `isToday` only in offset-0 month, computed against `today` parameter
  - [x] Weekends via `calendar.isDateInWeekend` on concrete dates — never hardcoded
    Sat/Sun (§4.3)
  - [x] Week numbers: `weekOfYear` of each row's first day; force
    `minimumDaysInFirstWeek = 4` when effective first day is Monday (ISO-8601) (§4.3)
  - [x] `year` field populated for boundary detection (§4.3, §4.4)

### Unit tests — Swift Testing (§5)

- [x] Fixtures: Mon-first, Sun-first, Fri–Sat-weekend calendars (fixed, not
  `autoupdatingCurrent`)
- [x] Leap February; 4-, 5-, 6-row months (Aug 2026 Mon-first = 6 rows)
- [x] Year boundaries: Dec ± 1, Jan ± 1 via `.month` arithmetic (§4.10)
- [x] All 7 first-day overrides: header rotation ↔ row layout consistency
- [x] Week numbers: ISO vs US numbering; W52/W53/W1 boundaries (2026 is a W53 ISO year)
- [x] `isToday` never true in offset ±1 months
- [x] `year` metadata across Dec/Jan spans

### Views (§4.4, §4.5)

- [x] `Theme.swift`: semantic colors only — `.primary`, `.secondary`, `Color.red`,
  `Color(nsColor: .separatorColor)`; type metrics from the §4.4 table
- [x] `MonthGridView`:
  - [x] Title 13 pt bold red, leading-aligned; header 11 pt semibold; days 12 pt
    semibold, monospaced digits
  - [x] Weekend columns `.secondary` (header + days)
  - [x] Today: filled red circle, white number, diameter ≈ 1.7 × cap height
  - [x] Fixed 6-row grid height — no layout shift between 5- and 6-row months (§4.4,
    §4.10)
  - [x] Optional week-number leading column: 9 pt medium `.secondary`, right-aligned,
    blank header cell (§4.4)
- [x] `MultiMonthView`:
  - [x] Span ↔ family mapping: small = 1, medium = 2 side by side, large = 3
    (prev/current top, next bottom-leading), XL = 3 in a row; `min(span, capacity)`
    fallback (§3) — `displayedOffsets`, unit-tested
  - [x] Type scale steps down one notch for ≥ 2 months (§4.4)
- [x] `YearBoundaryDivider`: 1 px `separatorColor` line, slightly inset; horizontal
  when stacked, vertical when side by side; rendered on `MonthModel.year` mismatch;
  isolated component — future asset swap-point (§4.4, §9)
- [ ] Preview matrix: 4 families × {1,2,3 months} × {light, dark} ×
  {fullColor, vibrant} × {week numbers on/off}; fixed Dec/Jan fixture for the divider
  (§5) — starter previews are in the view files; full matrix is an Xcode-canvas pass

## M2 — Widget extension (§8 M2, 2–3 d)

- [x] `ConfigurationIntent.swift`: `MonthSpan`, `Companion`, `FirstWeekday` AppEnums +
  `CalendarConfigIntent` with conditional `parameterSummary` (companion only when
  span == two) — code as in §4.2
- [x] `Provider.swift`: 3 entries (now + next two midnights via `Calendar`), `.atEnd`
  policy — code as in §4.6 (`timelineDates` extracted into `QuaterlyCore` for testing)
- [x] `CalendarWidget.swift`: `AppIntentConfiguration`, kind
  `com.antavik.quaterly.calendar`, `.containerBackground(.background, for: .widget)`,
  display name "Calendar" (§4.2)
- [x] Families: small/medium/large always; `systemExtraLarge` behind
  `if #available(macOS 15, *)` (§4.2, §4.10)
- [x] `.widgetURL(URL(string: "quaterly://open-calendar")!)` on every view, all
  families (§4.9)
- [x] `QuaterlyWidgetBundle.swift`
- [x] Provider unit tests: entry count, midnight alignment across DST (§5) — via
  `timelineDates` tests in `QuaterlyCoreTests`
- [ ] Visual parity pass: overlay comparison vs Apple widget screenshots, tune point
  values per family/appearance (§4.4, §5) — manual, needs a running system
- [ ] Verify `\.widgetRenderingMode` behavior — today marker survives desktop
  vibrant/tinted fade (§4.5) — manual, needs a running system

## M3 — Host app (§8 M3, 2 d)

- [x] `QuaterlyApp.swift` + `AppDelegate.swift`:
  - [x] URL relay: handle `quaterly://open-calendar` without showing a window; read
    `launchCalendarScheme` from App Group defaults; `NSWorkspace.open` (§4.9)
  - [x] Fallback: if `open` fails, launch `com.apple.iCal` via
    `urlForApplication(withBundleIdentifier:)` (§4.9)
  - [x] Terminate after relay when no window visible — no resident process (§4.11)
  - [x] Reopen (Finder/Spotlight) shows onboarding/settings window (§4.7)
- [x] Onboarding window, 3 steps: Desktop add, Notification Center add, per-widget
  configuration (§4.7) — v1 uses text + SF Symbols; screen recordings still to produce
- [x] Placement detection: poll `WidgetCenter.shared.getCurrentConfigurations` every
  2 s **only while onboarding visible**; flip step to "Widget added ✓"; timer dies with
  the window (§4.7, §4.11)
- [x] Settings window: `launchCalendarScheme` editor (advanced), stored in App Group
  suite (§4.8)
- [x] `WidgetCenter.shared.reloadAllTimelines()` on settings change — and nowhere else
  (§4.6, §4.11); saved on submit, not per keystroke
- [x] Closing last window terminates the app (§4.11)

## M4 — QA & distribution (§8 M4, 2–3 d)

- [x] Snapshot smoke tests via `ImageRenderer` — native only, no third-party snapshot
  library (§5, G11); reference-image regression comparison still to add
- [x] Performance tests: XCTest `measure` with XCTClockMetric/XCTMemoryMetric on
  `monthModel` + timeline build vs §4.11 budgets (< 50 ms build, < 15 MB peak)
- [ ] Instruments one-off audit: Time Profiler + Allocations (§5) — manual
- [ ] Activity Monitor checks: extension absent between reloads; host absent after
  relay and after window close (§4.11, §5) — manual
- [ ] Manual integration matrix: add/remove/edit widget on Desktop + Notification
  Center; click-through to Calendar and Fantastical; live appearance switch; "reduce
  transparency" mode (§5)
- [x] Edge-case verification against §4.10 table — unit-testable rows covered
  (year boundary, W53, first-day row count, 6-row months); locale switch/TZ travel/app
  deletion are system behaviors verified manually
- [ ] Onboarding "Troubleshooting" step: gallery cache remedies (§7)
- [ ] Developer ID signing + notarization; drag-to-/Applications DMG (§6) — needs the
  real development team
- [x] CI: build + tests + empty-`dependencies` check (G11) — `.github/workflows/ci.yml`
- [x] README

---

**Definition of done per milestone:** all boxes checked, tests green, no budget
regressions, doc cross-references still accurate.
