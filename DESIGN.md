# Leap — macOS Calendar Widget

**Design document · v2.4 · 2026-08-12**

A macOS app that installs and configures a calendar widget rendering one, two, or three
months, placeable on the Desktop and in Notification Center, visually matching Apple's
built-in Calendar month widget, following the system light/dark appearance, and opening
the user's default calendar application on click. Native tooling only: Swift, SwiftUI,
WidgetKit, AppKit, Xcode. Zero third-party dependencies.

---

## 1. Goals

| # | Requirement |
|---|-------------|
| G1 | Render **1 month** (current), **2 months** (current + previous *or* next), **3 months** (previous + current + next) |
| G2 | Placement on **Desktop** and in **Notification Center** |
| G3 | **Light/dark theme** follows macOS appearance automatically |
| G4 | Visual parity with the **default macOS Calendar month widget** (reference screenshot) |
| G5 | **Click opens the default calendar application** |
| G6 | Host app **installs** (registers) the widget and provides **configuration** |
| G7 | 100 % native toolchain (Swift / SwiftUI / WidgetKit / AppKit) |
| G8 | Option to show a **week numbers** column |
| G9 | Option to choose the **first day of the week** (system default or an explicit weekday) |
| G10 | **Minimal footprint** — near-zero idle CPU and memory; the app must feel weightless (§4.11) |
| G11 | **Zero third-party dependencies** — Apple SDKs only; no SPM/CocoaPods/Carthage packages, build or runtime. The local `LeapCore` package (§4.1) is first-party code, not a dependency |

### Non-goals (v1)

- Displaying events, reminders, or availability (no EventKit — therefore **no privacy
  permission prompts** at all).
- Alternate calendars (Hebrew/Islamic overrides), custom accent colors. Listed as
  future work in §9.
- iOS/iPadOS targets (architecture keeps the door open — all rendering is pure SwiftUI).

---

## 2. Platform facts that shape the design

These are hard constraints of macOS; the architecture is designed around them.

1. **Widgets cannot be placed programmatically.** There is no public API to add a widget
   to the Desktop or Notification Center. The system-owned flow is: right-click Desktop →
   *Edit Widgets…*, or Notification Center → *Edit Widgets*. An app can only *register*
   its widget extension (by being launched once) and *guide* the user.
2. **Desktop widgets require macOS 14 Sonoma+.** Notification Center widgets exist since
   macOS 11. `AppIntentConfiguration` (modern per-widget configuration) requires
   macOS 14. `systemExtraLarge` family requires macOS 15.
3. **Widget click behavior:** `widgetURL(_:)` / `Link` open the *containing* app with the
   URL. Opening a *different* app (Calendar) is done by relaying through the host app,
   which resolves the default handler of the `ical://` scheme via Launch Services — this
   respects users whose default calendar is Fantastical/BusyCal, not just Apple Calendar.
4. **Desktop widgets are system-tinted.** When the user focuses an app window, Sonoma
   fades desktop widgets to a monochrome/vibrant style. Views must use semantic colors
   and respect `\.widgetRenderingMode` so tinting is handled by the system, not fought.
5. **Widget extensions must be sandboxed**; the extension renders on the system's
   schedule (archived SwiftUI views), so all date logic must be timeline-driven — no
   timers inside views.

---

## 3. Architecture — single configurable WidgetKit widget

One widget kind. The user adds it in any size and configures it in place
(right-click → *Edit Widget*): month span (1/2/3), direction for the 2-month span
(previous/next), first day of week, and week numbers on/off.

```
┌────────────────────────────┐        ┌─────────────────────────────┐
│ Leap.app (host, LSUI)  │        │ LeapWidget.appex        │
│  • onboarding / guide      │        │  • AppIntentConfiguration   │
│  • settings window         │  App   │  • TimelineProvider         │
│  • URL relay:              │ Group  │  • MonthGridView (SwiftUI)  │
│    leap:// → ical://   │◀──────▶│  • widgetURL(leap://)   │
└──────────────┬─────────────┘        └─────────────────────────────┘
               │ NSWorkspace.open(ical://)
               ▼
      Default calendar app (Calendar / Fantastical / BusyCal)
```

- **Month span ↔ family mapping:** `systemSmall` → 1 month; `systemMedium` → 2 months
  side by side; `systemLarge` → 3 months; `systemExtraLarge` (macOS 15+) → 3 months in
  one row. If the configured span doesn't fit the family, render `min(span, capacity)`.
- **Min target:** macOS 14 (Desktop widgets + AppIntents; in 2026 this is a safe floor).
- **Properties that follow from the architecture:** real system widget on Desktop *and*
  in Notification Center with native add/remove/tint/Stage Manager behavior; automatic
  light/dark; per-instance configuration (a 1-month small and a 3-month large can
  coexist); host app not resident — the system renders the widget. Known trade-offs:
  placement stays manual (constraint #1) and configuration hides behind right-click —
  both mitigated by onboarding (§4.7).

---

## 4. Detailed design

### 4.1 Targets & modules

```
leap/
├── Leap.xcodeproj
├── Leap/                    # Host app target (SwiftUI, macOS 14+)
│   ├── LeapApp.swift        # @main; activation policy .accessory (LSUIElement)
│   ├── AppDelegate.swift        # URL relay, reopen handling
│   ├── Onboarding/              # install guide (§4.7)
│   └── Settings/                # defaults editor (§4.8)
├── LeapWidget/              # Widget extension target (macOS 14+)
│   ├── LeapWidgetBundle.swift
│   ├── CalendarWidget.swift     # Widget + AppIntentConfiguration
│   ├── ConfigurationIntent.swift
│   └── Provider.swift           # TimelineProvider
└── LeapCore/                # Local Swift package, shared by both targets
    ├── CalendarMath.swift       # month grids, pure functions — fully unit-tested
    ├── MonthModel.swift
    ├── WidgetConfig.swift       # per-instance render config, model pipeline, year label
    ├── WidgetKind.swift         # widget kind identifiers
    ├── ClickPreset.swift        # preset click targets (relay wire format)
    ├── Theme.swift              # semantic colors, metrics (§4.4)
    └── Views/
        ├── MonthGridView.swift
        └── MultiMonthView.swift
```

- Bundle IDs: `com.antavik.leap` / `com.antavik.leap.widget`.
- App Group: `<TEAMID>.com.antavik.leap` (shared `UserDefaults` suite). On macOS the
  group ID must be **Team-ID-prefixed** — the iOS-style `group.*` form is not backed by
  provisioning for Developer ID apps and triggers a user consent prompt on macOS 15+.
- Host app runs as `.accessory` (no Dock icon); it shows its onboarding window on first
  launch and whenever the app is reopened from Finder/Spotlight. This keeps the URL
  relay (§4.9) invisible — no Dock bounce when a widget is clicked.

### 4.2 Configuration model (App Intent)

```swift
enum MonthSpan: String, AppEnum { case one, two, three }      // "1 Month", "2 Months", "3 Months"
enum Companion: String, AppEnum { case previous, next }        // second month for span == .two
enum FirstWeekday: String, AppEnum {                           // "System Default", "Monday", …
    case system, monday, tuesday, wednesday, thursday, friday, saturday, sunday
}

struct CalendarConfigIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Calendar Options"

    @Parameter(title: "Months", default: .one)
    var span: MonthSpan

    @Parameter(title: "Second Month", default: .next)
    var companion: Companion

    @Parameter(title: "First Day of Week", default: .system)
    var firstWeekday: FirstWeekday

    @Parameter(title: "Week Numbers", default: false)
    var showWeekNumbers: Bool

    static var parameterSummary: some ParameterSummary {
        When(\.$span, .equalTo, .two) {
            Summary("Show \(\.$span)") {             // companion shown only for 2-month span
                \.$companion
                \.$firstWeekday
                \.$showWeekNumbers
            }
        } otherwise: {
            Summary("Show \(\.$span)") {
                \.$firstWeekday
                \.$showWeekNumbers
            }
        }
    }
}
```

Three-month span is fixed to *previous + current + next* per G1 — no direction
parameter. Widget declaration:

```swift
AppIntentConfiguration(kind: "com.antavik.leap.calendar",
                       intent: CalendarConfigIntent.self,
                       provider: Provider()) { entry in
    MultiMonthView(entry: entry)
        .containerBackground(.background, for: .widget)                // §4.4
}
.configurationDisplayName("Calendar")
.description("Month view — one, two, or three months at a glance.")
.supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge])
```

(`systemExtraLarge` included behind an `if #available(macOS 15, *)` split of the
families array.)

**As shipped:** two widget kinds instead of one, because a single intent cannot vary
its parameters per family — the small size has no companion direction, and the
two-month size has no month picker.

| Kind | Gallery name | Family | Intent | Month choice |
|------|--------------|--------|--------|--------------|
| `com.antavik.leap.calendar` | Two Months | `systemMedium` | `CalendarConfigIntent` | current + previous *or* next |
| `com.antavik.leap.calendar.small` | Month | `systemSmall` | `SmallCalendarConfigIntent` | current, previous, *or* next |

Both intents conform to `CalendarConfiguration` and therefore share first weekday,
week numbers, adjacent-month days, year label, and click target verbatim; both render
through `MultiMonthView`, so the small widget is exactly the one-model path at the
same `Theme.compact` scale as the two-month widget — element sizes match across
families. The small widget's year label follows the *displayed* month's
year, not today's — they differ when the neighbour month crosses a year boundary.
The today marker stays confined to the offset-0 month, so a previous/next small
widget shows no marker.

Click handling: when the configured action resolves to a target, the content carries
`widgetURL` (relayed through the host app). When it resolves to nothing — "Nothing",
or a custom action with an empty URL — the content is wrapped in an interactive
no-op `Button(intent:)` instead: the click is swallowed inside the widget process,
because a bare `widgetURL` would launch the host app just to do nothing, and rapid
clicks can race that launch-and-quit into showing the app window. (Each no-op click
still triggers WidgetKit's post-intent timeline reload — three-entry rebuild,
microseconds, acceptable.)

Relay hardening: `leap://` is registered system-wide, so any process — or a web
page after a single consent prompt — can invoke it; the app must not act as a
confused deputy that opens arbitrary URLs. Presets therefore travel as opaque
tokens (`?action=appleCalendar`) resolved against `ClickPreset` in the app; only
user-typed custom targets put a real URL on the wire (`?url=…`), and the app
rejects path-launching schemes there (`file`, `smb`, `afp`, `nfs`, `ftp`, `cifs`).
Residual risk — laundering a third-party URL scheme through the custom channel —
is accepted: it requires the user to have consented to opening Leap, and matches
what any locally running process could already do directly.

### 4.3 Calendar mathematics (`LeapCore`)

Pure, deterministic, fully testable — the widget provider and any future surface consume
the same functions.

```swift
struct MonthOptions: Equatable {
    let firstWeekday: Int?         // nil = system; else 1 = Sunday … 7 = Saturday (Calendar convention)
    let showWeekNumbers: Bool
}

struct MonthModel: Equatable {
    let title: String              // "AUGUST" — uppercased standalone month symbol
    let year: Int                  // for year-boundary detection (§4.4)
    let weekdayHeaders: [String]   // very-short standalone symbols, rotated by effective first weekday
    let weeks: [[Day?]]            // 7-column rows; nil = leading/trailing blank
    let weekNumbers: [Int]?        // one per row; nil when option is off
}
struct Day: Equatable { let number: Int; let isToday: Bool; let isWeekend: Bool }

func monthModel(containing date: Date,
                offset: Int,                       // -1, 0, +1
                calendar: Calendar,                // Calendar.autoupdatingCurrent
                today: Date,
                options: MonthOptions) -> MonthModel
```

Rules:

- `Calendar.autoupdatingCurrent` throughout → first weekday (Mon vs Sun), month/weekday
  symbols, and weekend days all follow the user's region settings, matching what Apple's
  widget shows (reference screenshot is a Monday-first locale).
- **Effective calendar:** a copy of the input calendar with `firstWeekday` overridden
  when `options.firstWeekday != nil`. Row layout, weekday-header rotation, *and* week
  numbering all derive from this one effective calendar, so the three can never
  disagree. Weekend detection stays `isDateInWeekend` — independent of the first-day
  choice (Saturday stays gray whether the week starts Monday or Sunday).
- **Week numbers:** `weekOfYear` of each displayed row's first day, computed with the
  effective calendar. When the effective first day is Monday, `minimumDaysInFirstWeek`
  is forced to 4 → ISO-8601 numbering (what Apple Calendar shows in Monday-first
  regions); otherwise the calendar's regional numbering applies. Rows belonging to the
  adjacent year keep the number the calendar assigns (52/53 before W1 — see §4.10).
- **Year boundary:** in multi-month spans, a boundary exists between adjacent displayed
  months whose `year` differs (…Dec 2026 | Jan 2027…). `CalendarMath` only exposes the
  metadata (`year` per month); the visual treatment is a rendering concern (§4.4).
- Blank leading/trailing cells (Apple style) — **no** dimmed adjacent-month days.
- `isToday` computed against the timeline entry's date, only ever true in the
  offset-0 month.
- Weekend columns come from `calendar.isDateInWeekend` on concrete dates, not hardcoded
  Sat/Sun (handles regions with Fri–Sat weekends).

### 4.4 Rendering spec — parity with the Apple widget

Derived from the reference screenshot (`systemSmall`, light):

| Element | Spec |
|---|---|
| Container | System widget container; default corner radius; `containerBackground(for: .widget)` — no custom chrome, so Desktop tinting works |
| Background | Light: system widget background (white); Dark: elevated dark gray — via semantic background, never hardcoded |
| Month title | Uppercased standalone month name; `.system(size: 13, weight: .bold)`; color `Color.red` (system red, matches Apple's) ; leading-aligned |
| Weekday header | Very-short standalone symbols (M T W T F S S); `.system(size: 11, weight: .semibold)`; weekdays `.primary`, weekend columns `.secondary` |
| Day numbers | `.system(size: 12, weight: .semibold)`, monospaced digits; weekdays `.primary`, weekends `.secondary` |
| Today | Filled circle, system red; number in white, same weight; circle diameter ≈ 1.7 × font cap height |
| Grid | `Grid`/`LazyVGrid`, 7 equal columns, tight vertical leading; up to 6 week rows — row height fixed for 6 rows so months with 5 vs 6 weeks don't shift the header |
| Week numbers (optional) | Extra narrow **leading** column: `.system(size: 9, weight: .medium)`, `.secondary`, right-aligned digits; blank header cell; day columns compress evenly. Apple's widget has none — parity (G4) applies with the option **off**; when on, styling follows Apple Calendar's week-number treatment |
| Multi-month | Medium: two `MonthGridView`s in `HStack` with a hairline of spacing; Large: three months (prev/current top row, next bottom-leading) ; ExtraLarge: three in one row; type scale steps down one notch for ≥2 months |
| Year boundary | No divider (removed after v1 trial — visual noise). Month titles stay year-less (Apple style); the optional `’26` year label is the only year cue |

Exact point values are tuned against side-by-side screenshots of the Apple widget during
implementation (Xcode widget previews at all families, both appearances); the table
above is the starting spec.

### 4.5 Theming

- **Zero custom color literals.** Only `Color.primary`, `.secondary`, `Color.red`,
  and the semantic widget background.
  Light/dark (G3) then costs nothing: SwiftUI re-renders the archived view for the
  active appearance.
- Respect `\.widgetRenderingMode`: in the faded Desktop state the system remaps content
  to a monochrome material by luminance. Keep the today marker a *filled shape* (it
  survives desaturation as a solid disc), avoid opacity tricks that collapse contrast
  when color is stripped, and verify legibility in the preview matrix (§5).
- No images or gradients in v1 — pure text + shapes keeps every rendering mode crisp.
  The future year-boundary asset (§9) is the planned exception: before it replaces the
  v1 separator line it must ship light/dark variants **and** degrade cleanly in
  `.vibrant`/tinted desktop mode (template image or luminance-only), or fall back to the
  line there.

### 4.6 Timeline & refresh

Content changes exactly once a day (plus locale/timezone events the system already
handles by reloading widgets):

```swift
func timeline(for config: CalendarConfigIntent, in context: Context) async -> Timeline<Entry> {
    let calendar = Calendar.autoupdatingCurrent
    let now = Date()
    let todayStart = calendar.startOfDay(for: now)
    let midnights = (1...2).compactMap { calendar.date(byAdding: .day, value: $0, to: todayStart) }
    let entries = ([now] + midnights).map { Entry(date: $0, config: config) }
    return Timeline(entries: entries, policy: .atEnd)
}
```

- One entry now + entries at the next two midnights, `.atEnd` → today's highlight flips
  at 00:00 with zero daily budget pressure (WidgetKit refresh budget is irrelevant at
  ~1 reload/day).
- DST transitions are safe because midnights come from `Calendar`, not `+86400`.
- Host app calls `WidgetCenter.shared.reloadAllTimelines()` after any settings change.

### 4.7 Install & configure flow (host app)

“Install” on macOS means: *register the extension, then walk the user through the
system's add-widget flow* (constraint #1).

1. **First launch** (user opens Leap.app, e.g. after dragging to /Applications):
   LaunchServices/PluginKit registers `LeapWidget.appex` automatically — the widget
   now appears in the system widget gallery. No further "installation" exists or is
   possible.
2. **Onboarding window** (SwiftUI, 3 steps, with short screen recordings):
   - *Desktop:* right-click Desktop → **Edit Widgets…** → search "Leap" → drag to
     Desktop.
   - *Notification Center:* click the menu-bar clock → scroll down → **Edit Widgets**.
   - *Configure:* right-click the placed widget → **Edit “Calendar”** → choose Months /
     Second Month / First Day of Week / Week Numbers.
3. **Placement detection:** the app polls `WidgetCenter.shared.getCurrentConfigurations`
   while onboarding is visible; when the user's widget appears, the step flips to a
   checkmark ("Widget added ✓") — closes the guidance loop without any private API.
4. **Reopen behavior:** launching the app again shows the same window (Settings +
   re-runnable guide).

Dev note (not shipped): during development the gallery can cache stale metadata —
`killall NotificationCenter chronod` and `pluginkit -m -i com.antavik.leap.widget`
are the standard remedies.

### 4.8 Settings (App Group)

Per-instance options live in the widget's own intent (§4.2) — that is the primary
configuration surface. The host app's Settings window holds only cross-instance
defaults, stored in `UserDefaults(suiteName: "<TEAMID>.com.antavik.leap")` (§4.1):

| Key | Default | Notes |
|---|---|---|
| `launchCalendarScheme` | `ical://` | Advanced: alternate scheme (e.g. `x-fantastical3://`) if the user wants clicks routed to a specific app instead of the `ical` default handler |
| (future) `accent` | — | §9 |

### 4.9 Click → default calendar app

- Every widget view sets `.widgetURL(URL(string: "leap://open-calendar")!)`
  (small family supports only `widgetURL`; using the same single target on all families
  keeps behavior uniform — the whole widget is one click surface, like Apple's).
- Host app declares the `leap` URL scheme (`CFBundleURLTypes`) and handles it in the
  AppDelegate **without showing any window**:

```swift
func application(_ app: NSApplication, open urls: [URL]) {
    guard urls.contains(where: { $0.host == "open-calendar" }) else { return }
    let scheme = settings.launchCalendarScheme         // §4.8; default "ical://"
    NSWorkspace.shared.open(URL(string: scheme)!)      // Launch Services → user's default calendar app
}
```

- `ical://` resolves through Launch Services to whatever app the user has set as
  default for calendar URLs — Apple Calendar out of the box, Fantastical/BusyCal if the
  user chose them. This is the correct reading of "default calendar application" (G5).
- Failure fallback: if `open` returns false, open Apple Calendar explicitly via
  `NSWorkspace.urlForApplication(withBundleIdentifier: "com.apple.iCal")`.

### 4.10 Edge cases

| Case | Handling |
|---|---|
| Month with 6 week-rows (e.g. Aug 2026, Mon-first) | Fixed 6-row grid height (§4.4) — no layout jump between months |
| Year boundary (Dec ± 1, Jan ± 1) | `calendar.date(byAdding: .month,…)` — covered by unit tests |
| Locale switch (first weekday, symbols, RTL) | `autoupdatingCurrent` + system widget reload on locale change; explicit first-day override wins over locale; layout uses leading/trailing, never left/right |
| First-day override changes row count (e.g. a month needs 6 rows Mon-first but 5 Sun-first) | Grid, header, and week numbers all derive from one effective calendar; fixed 6-row height absorbs the difference |
| Week 52/53 → W1 at year boundary | Week number computed per displayed row from the effective calendar; W53 years (e.g. 2026 ISO) covered by unit tests |
| Displayed span crosses New Year (Dec \| Jan adjacent) | No divider (§4.4); `MonthModel.year` metadata retained — the small widget's year label follows the displayed month's year |
| Timezone travel | System reloads widgets on TZ change; entries are TZ-relative |
| Host app deleted | System removes the app's widgets from Desktop/Notification Center automatically — no dangling click targets |
| macOS 15 `systemExtraLarge` | Families gated with `#available`; macOS 14 users simply don't see XL |

### 4.11 Performance budget & optimisation

The architecture is itself the main optimisation: a WidgetKit widget is **not a running
process**. The extension wakes briefly to build a timeline, the system archives the
SwiftUI views and displays the snapshots (`chronod`), and the extension is terminated.
With ~1 reload/day (§4.6), steady-state cost is zero CPU and zero resident memory for
both surfaces — the design's job is to not break that property.

Budgets (verified in §5):

| Metric | Budget | Why it holds |
|---|---|---|
| Widget: timeline build | < 50 ms per daily reload (Apple-silicon baseline) | 3 entries; ≤ 3 months × 42 cells of pure value-type math |
| Widget: peak memory during build | < 15 MB (WidgetKit enforces a low cap — ~30 MB documented for iOS widgets, macOS comparably strict) | text + shapes only; no image assets; no caches |
| Widget: steady state | 0 CPU; extension process absent | system snapshot model + `.atEnd`; no periodic reloads |
| Host app: steady state | not running — 0 CPU, 0 MB | `.accessory` app terminates when idle (below) |
| Host app: URL relay | < 300 ms from click to hand-off (`NSWorkspace.open` issued); no resident process left behind. Calendar app launch time itself is outside our control | handle URL → open → terminate |

Rules:

- **No timers, observers, or runloop wakeups in steady state.** The only recurring event
  is the system-driven midnight entry swap, which costs nothing in-process. The single
  exception is the onboarding placement poll (§4.7): a 2 s timer that exists only while
  the onboarding window is visible and dies with it.
- **Reload discipline:** `reloadAllTimelines()` fires only on an actual settings change
  (§4.8) — never as periodic "refresh insurance". Every redundant reload wakes the
  extension once per placed widget.
- **No formatter churn:** month/weekday symbols come from `Calendar` once per
  `monthModel` build; no `DateFormatter` is ever created in view code (the classic
  hidden CPU sink).
- **Cheap view tree:** flat text + shape hierarchy; no shadows, blurs, animations, or
  `TimelineView`. Fast to archive, small snapshots, crisp in every rendering mode
  (§4.5).
- **Host app lifecycle:** the relay (§4.9) opens the calendar URL and then calls
  `NSApp.terminate` when no window is visible — a widget click leaves no process
  behind. Closing the onboarding/settings window likewise terminates the app.
- **Value-type models only:** a full 3-month `MonthModel` set is under 1 KB; nothing to
  cache, nothing to invalidate, nothing to leak.

---

## 5. Testing

| Layer | Approach |
|---|---|
| `CalendarMath` | Unit tests (Swift Testing): fixed `Calendar` fixtures — Mon-first, Sun-first, Fri–Sat weekend regions; leap Feb; 4/5/6-row months; year boundaries; DST midnights; `isToday` only in offset-0; all 7 first-day overrides (header rotation ↔ row layout consistency); week numbers — ISO vs US numbering, W52/W53/W1 boundaries; `year` metadata across Dec/Jan spans |
| Views | Xcode Previews matrix: 4 families × {1,2,3 months} × {light, dark} × {fullColor, vibrant} × {week numbers on/off}; fixed Dec/Jan fixture for year-boundary layouts; snapshot tests via `ImageRenderer` for regression |
| Parity (G4) | Manual overlay comparison against Apple's widget screenshots per family/appearance |
| Timeline | Unit test provider output: entry count, midnight alignment across DST |
| Integration | Manual: add/remove/edit widget on Desktop + Notification Center; click-through to Calendar, Fantastical; appearance switch live; "reduce transparency" accessibility mode |
| Performance (G10) | XCTest `measure` test (XCTClockMetric/XCTMemoryMetric — Swift Testing has no measurement API) on `monthModel` + timeline build vs §4.11 budgets; Instruments (Time Profiler, Allocations) one-off audit; Activity Monitor checks — extension absent between reloads, host process absent after relay and after window close |

## 6. Distribution

- Both targets sandboxed (widget extensions require it); Hardened Runtime on.
- Primary channel: **Developer ID + notarization**, distributed as drag-to-/Applications
  DMG (widget registration is most reliable from /Applications).
- App Store optional later — host app has real UI (onboarding/settings), so it clears
  the "not just a widget shell" review bar.
- No entitlements beyond App Sandbox + App Group. **No network, no EventKit, no privacy
  prompts** — a selling point worth stating in the app.
- **Dependency policy (G11):** Apple SDKs only — no third-party packages anywhere,
  including tests (snapshots via native `ImageRenderer`, §5, not an external snapshot
  library). Consequences: nothing to license-audit, no supply-chain surface to notarize
  around, no dependency updates to chase, and `Package.swift` of `LeapCore` declares
  an empty `dependencies: []` — CI fails the build if that ever changes.

## 7. Risks

| Risk | Sev | Mitigation |
|---|---|---|
| Users expect the app to *place* the widget (G6 vs constraint #1) | M | Onboarding with recordings + live "Widget added ✓" detection (§4.7); App Store screenshots show the flow |
| Visual drift from Apple's widget across OS releases | L | Parity is spec-by-screenshot (§4.4); re-run overlay comparison each macOS beta |
| Gallery doesn't show widget after install (PluginKit cache) | L | Onboarding "Troubleshooting" step: relaunch app, log out/in; dev remedies in §4.7 |
| macOS 14 floor excludes older Macs | L | Accepted for v1; alternatives evaluated in v1.x (static widget kinds for macOS 11+ Notification Center; desktop-overlay agent) can be revisited if demand appears |

## 8. Milestones

1. **M1 (2–3 d):** `LeapCore` — models, math, unit tests; `MonthGridView` with preview matrix.
2. **M2 (2–3 d):** Widget extension — intent, provider, families, containerBackground, widgetURL; visual parity pass.
3. **M3 (2 d):** Host app — URL relay, onboarding with placement detection, settings.
4. **M4 (2–3 d):** QA matrix (§5) incl. performance budgets (§4.11), notarized DMG, README.

## 9. Future work

Event dots via EventKit (opt-in, brings permission prompt) ·
custom accent colors · month paging via interactive widget buttons (AppIntents) ·
iOS/iPadOS widget from the same `LeapCore` · localization pass.
