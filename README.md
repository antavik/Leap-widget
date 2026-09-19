# Leap

A macOS calendar widget for the Desktop and Notification Center, visually matching
Apple's built-in Calendar month widget. Shows the current month plus a configurable
neighbor; follows the system light/dark appearance; clicking a widget opens your
default calendar application.

100 % native — Swift, SwiftUI, WidgetKit, AppKit. Zero third-party dependencies.

## Requirements

- macOS 14 Sonoma or later (Desktop widgets, per-widget configuration)
- Xcode 16+ to build
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`) — the
  `.xcodeproj` is generated from `project.yml`, not committed

## Features

- **Two widgets**: *Two Months* (medium) shows 2 months — current + previous
  *or* next; *Month* (small) shows a single month — current, previous, or next
- **Desktop and Notification Center** placement, small and medium widget sizes
- **Light/dark** follows macOS automatically, including the faded Desktop style
- **Week numbers** (optional) — ISO-8601 in Monday-first layouts, regional otherwise
- **First day of week** — system default, Monday, or Sunday
- **Click → the calendar you choose** — per-widget dropdown: default calendar
  (`ical://`), Fantastical, or Google Calendar
- No events shown, no EventKit — **no privacy prompts, no network**

## Building

```sh
make test

make release
```

`make release` and `make debug` regenerate the project first. Run `make project`
on its own before opening Xcode, and again after adding or removing a source
file so the target picks it up.

The About panel's build number is the short hash of the built commit, stamped in
by `make`. Building straight from Xcode shows `dev` instead.

Build settings live in `Config/*.xcconfig`, target structure in `project.yml`.
Edit those rather than Xcode's build-settings UI — Xcode writes overrides into
the generated `.xcodeproj`, which the next `make project` throws away.

Before signing for distribution, set your development team on both targets — no
other signing configuration is needed.

## Using

1. Launch Leap once — that registers the widget with macOS.
2. Right-click the Desktop → **Edit Widgets…** → search “Leap” → drag out
   **Two Months** or **Month** — or add either from Notification Center's
   **Edit Widgets**.
3. Right-click the placed widget → its **Edit** item to choose which months to
   show, first day of week, week numbers, and which app a click opens — each
   widget keeps its own settings.

The app's window guides you through these steps. The app doesn't stay running —
widgets are rendered by the system.

## Uninstalling

Open Leap and choose **Help ▸ Uninstall Leap…**. Leap moves itself and its settings
to the Trash and quits; the widgets disappear on their own. If Leap was installed
with Homebrew it hands the job to `brew` instead, so Homebrew's own records stay
correct.

macOS keeps `~/Library/Containers` out of reach of every app but Finder, so the two
sandbox containers survive. Leap names them on the way out and offers to reveal them
in Finder, where dragging them to the Trash finishes the job. No password lifts this
— it is Full Disk Access, not a privilege `sudo` can grant.

From the terminal, a Homebrew install comes out with:

```sh
brew uninstall --cask --zap leap
```

Without `--zap` the app goes but its settings stay — that is Homebrew's
convention, not Leap's.

Dragging Leap to the Trash also works and leaves a few megabytes behind. To clear
those out by hand:

```sh
rm -rf ~/Library/Preferences/com.antavik.leap.plist \
       ~/Library/Containers/com.antavik.leap \
       ~/Library/Containers/com.antavik.leap.widget \
       "$HOME/Library/Application Scripts/com.antavik.leap" \
       "$HOME/Library/Application Scripts/com.antavik.leap.widget" \
       "$HOME/Library/Saved Application State/com.antavik.leap.savedState" \
       ~/Library/Caches/com.antavik.leap
```

The two `Containers` entries need Full Disk Access on whichever terminal runs this
(System Settings ▸ Privacy & Security ▸ Full Disk Access); without it they refuse
to go, `sudo` included. Finder removes them with no setup. They are sandbox
leftovers: the widget still uses its container, and `com.antavik.leap` is left over
from versions up to 0.1.0, when the app was sandboxed too.

On a development machine, `make uninstall` clears the same paths for the copy in
`/Applications`, deleting them outright rather than moving them to the Trash.

## Testing

Five layers, fastest first. `make test` runs L0–L3 in a few seconds; L4 needs
Xcode and a logged-in GUI session.

| Layer | What it proves | Where |
|---|---|---|
| L0 | Facts duplicated across files still agree — uninstall paths, localized keys and their bundle spelling, the widget's option enums, the scheme/test-plan wiring and its safe-mode interlock | `scripts/check-*.sh` |
| L1 | Pure logic: calendar math, spoken labels, widget options, the `leap://` relay, uninstall escaping, the timeline | `LeapCore/Tests/LeapCoreTests` |
| L2 | Properties measured off a render: full opacity, clipping, the today marker, the week-number footprint, six rows, RTL | `LayoutInvariantTests` |
| L3 | Golden snapshots — 23 PNGs, the change detector for anything nobody thought to assert | `SnapshotTests`, images under `LeapCore/Tests/LeapCoreTests/__Goldens__/<os>-<xcode>/` |
| L4 | The app through a real accessibility client: menus, the About panel, the uninstall alert, `performAccessibilityAudit` — and the `leap://` relay a widget click sends, delivered as a real Apple Event | `LeapUITests`, driven by `Leap.xctestplan` |

```sh
make test                                                  # L0-L3
make report                                                # the same, plus reports/<stamp>-<hash>/
make snapshots-record                                      # regenerate goldens that moved
LEAP_SKIP_SNAPSHOTS=1 swift test --package-path LeapCore   # tightest loop
LEAP_BUDGETS=1 swift test --package-path LeapCore --filter BudgetTests

xcodebuild -project Leap.xcodeproj -scheme Leap -configuration Debug \
    -derivedDataPath build build-for-testing CODE_SIGN_IDENTITY="-" CODE_SIGN_STYLE=Manual
xcodebuild test-without-building -project Leap.xcodeproj -scheme Leap \
    -configuration Debug -derivedDataPath build -testPlan Leap \
    CODE_SIGN_IDENTITY="-" CODE_SIGN_STYLE=Manual
```

A golden diff means "look at this", not "this is wrong": inspect the expected,
actual and amplified-diff PNGs written to `reports/latest/screenshots/diff/`,
then fix the code or re-record. Goldens are committed *inputs*; everything
under `reports/` is a run's output and is git-ignored.

The UI tests move the mouse and take over the keyboard. Two of them reach
outside the test — the uninstall alert and the widget-click relay — and are
safe only because `Leap.xctestplan` sets `LEAP_UI_TEST_SAFE_MODE`, which
`LeapApp.launched()` forwards to the app. Under it `confirmUninstall` removes
nothing and says so before the destructive button can be clicked, and
`openCalendar` writes the resolved target to a file instead of opening it.

Two behaviours stay manual: that `widgetURL` is attached to the surface at all
(WidgetKit renders in another process, so no test host can click it), and that
a *cold* launch by URL relays and then quits (a sandboxed runner cannot arm the
interlock on one). The relay tests deliver the same Apple Event to a running
instance instead.

## Project layout

| Path | Contents |
|---|---|
| `Leap/` | Host app: onboarding, `leap://` → calendar URL relay |
| `LeapWidget/` | Widget extension: intent, timeline provider, widget declaration |
| `LeapCore/` | Local Swift package: calendar math, models, theming, widget options, the relay and the views — plus L0-L3 tests and the golden images |
| `LeapUITests/` | XCUITest target (L4), run through `Leap.xctestplan` |
| `scripts/` | L0 consistency checks and the report harness |

## License

TBD
