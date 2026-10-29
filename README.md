# Leap Widget

A macOS calendar widget for the Desktop and Notification Center, visually matching
Apple's built-in Calendar month widget. Shows the current month plus a configurable
neighbor; follows the system light/dark appearance; clicking a widget opens your
default calendar application.

100 % native – Swift, SwiftUI, WidgetKit, AppKit. Zero third-party dependencies.

## Requirements

- macOS 14 Sonoma or later (Desktop widgets, per-widget configuration)
- Xcode 16+ to build
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`) – the
  `.xcodeproj` is generated from `project.yml`, not committed

## Features

- **Two widgets**: *Two Months* (medium) shows 2 months – current + previous
  *or* next; *Month* (small) shows a single month – current, previous, or next
- **Desktop and Notification Center** placement, small and medium widget sizes
- **Light/dark** follows macOS automatically, including the faded Desktop style
- **Week numbers** (optional) – ISO-8601 in Monday-first layouts, regional otherwise
- **First day of week** – system default, Monday, or Sunday
- **Click → the calendar you choose** – per-widget dropdown: default calendar
  (`ical://`), Fantastical, or Google Calendar
- No events shown, no EventKit – **no privacy prompts, no network**

## Installing

With [Homebrew](https://brew.sh):

```sh
brew install --cask antavik/apps/leap-widget
```

Or download `Leap-Widget-<version>.dmg` from
[Releases](https://github.com/antavik/Leap-widget/releases), open it and drag
`Leap Widget.app` into **Applications**. Both are signed with a Developer ID and
notarized by Apple; a downloaded copy only asks once to confirm the first
launch, which the Homebrew cask skips.

## Building

```sh
make test

make release
```

`make help` lists every target. `make lint` runs SwiftLint in strict mode against `.swiftlint.yml`
(`brew install swiftlint`).

`make release` and `make debug` regenerate the project first. Run `make project`
on its own before opening Xcode, and again after adding or removing a source
file so the target picks it up.

The version is the latest `vX.Y.Z` git tag, passed in by `make`; builds made
after that tag keep its version, and the About panel's build number – the short
hash of the built commit – tells them apart. Building straight from Xcode shows
`0.0.0` and `dev` instead. `CFBundleVersion` is the build's Unix time, so every
build counts as an update to the widget host.

Build settings live in `Config/*.xcconfig`, target structure in `project.yml`.
Edit those rather than Xcode's build-settings UI – Xcode writes overrides into
the generated `.xcodeproj`, which the next `make project` throws away.

Local builds sign to run locally; only `make dist` (see
[Releasing](#releasing)) signs with Developer ID.

## Releasing

Leap Widget ships as a notarized Developer ID DMG, through this repository's GitHub
releases and the [antavik/homebrew-apps](https://github.com/antavik/homebrew-apps)
tap. `scripts/release.sh`, run by `make dist`, does every step.

`packaging/leap-widget.rb` is the cask's source of truth. The first publish copies it
into the tap; later releases rewrite only its `version` and `sha256` there, so
any other change to it has to be copied to the tap by hand.

Commands:

```sh
make dist VERSION=x.y.z             # build, sign, notarize, staple → build/Leap-Widget-x.y.z.dmg
make dist VERSION=x.y.z PUBLISH=1   # also: GitHub release + tag vx.y.z, cask bump in the tap
```

The version is given only here: publishing creates the `vx.y.z` tag that later
builds read theirs from, so nothing in the source has to be bumped. Without a
Developer ID identity in the keychain `make dist` still builds an ad-hoc DMG – a
dry run that `PUBLISH=1` refuses. Publishing tags the commit that was built, so
before building it refuses uncommitted changes, a commit not yet pushed, and a
version whose tag already points at another commit.
`LEAP_SIGN_IDENTITY` and `LEAP_NOTARY_PROFILE` override the identity and the
notary profile.

## Using

1. Launch Leap Widget once – that registers the widget with macOS.
2. Right-click the Desktop → **Edit Widgets…** → search “Leap Widget” → drag out
   **Two Months** or **Month** – or add either from Notification Center's
   **Edit Widgets**.
3. Right-click the placed widget → its **Edit** item to choose which months to
   show, first day of week, week numbers, and which app a click opens – each
   widget keeps its own settings.

The app's window guides you through these steps. The app doesn't stay running –
widgets are rendered by the system.

## Uninstalling

Open Leap Widget and choose **Help ▸ Uninstall Leap Widget…**. It moves itself
and its settings to the Trash and quits; the widgets disappear on their own. If
it was installed with Homebrew it hands the job to `brew` instead, so Homebrew's
own records stay correct.

macOS keeps `~/Library/Containers` out of reach of every app but Finder, so the two
sandbox containers survive. The app names them on the way out and offers to reveal them
in Finder, where dragging them to the Trash finishes the job. No password lifts this
– it is Full Disk Access, not a privilege `sudo` can grant.

From the terminal, a Homebrew install comes out with:

```sh
brew uninstall --cask --zap leap-widget
```

Without `--zap` the app goes but its settings stay – that is Homebrew's
convention, not Leap Widget's.

Dragging Leap Widget to the Trash also works and leaves a few megabytes behind. To clear
those out by hand:

```sh
rm -rf ~/Library/Preferences/com.antavik.leapwidget.plist \
       ~/Library/Containers/com.antavik.leapwidget \
       ~/Library/Containers/com.antavik.leapwidget.widget \
       "$HOME/Library/Application Scripts/com.antavik.leapwidget" \
       "$HOME/Library/Application Scripts/com.antavik.leapwidget.widget" \
       "$HOME/Library/Saved Application State/com.antavik.leapwidget.savedState" \
       ~/Library/Caches/com.antavik.leapwidget
```

The two `Containers` entries need Full Disk Access on whichever terminal runs this
(System Settings ▸ Privacy & Security ▸ Full Disk Access); without it they refuse
to go, `sudo` included. Finder removes them with no setup. They are sandbox
leftovers of the widget; the app itself is not sandboxed, so its own two entries
are normally absent and listed only for completeness.

On a development machine, `make uninstall` clears the same paths for the copy in
`/Applications`, deleting them outright rather than moving them to the Trash.

## The manual

The user manual lives in `docs/manual` as Markdown, with its screenshots in
`docs/manual/assets`. `scripts/build-help.sh` renders it into an Apple Help
Book – `build/help/Leap.help` – which the app target copies into
`Leap Widget.app/Contents/Resources`, so **Help ▸ Leap Widget Manual** (⌘?) opens it in Help
Viewer with no network. The search field AppKit puts at the top of the Help
menu searches the book's text, because `hiutil` indexes it at build time.

`make project` builds the book first: the generated project references it as a
resource, so it has to exist on disk. After editing a page, run `make project`
(or `make help-book`) before building, or Xcode keeps shipping the last one.

Markdown is rendered by `scripts/md2help.py`, a small subset renderer written
against the system Python – no packages to install. Write pages against what it
understands: headings, paragraphs, lists, pipe tables, fenced code,
blockquotes, and inline code, links, images, bold and italic.

## Testing

Five layers, fastest first. `make test` runs L0–L3 in a few seconds; L4 needs
Xcode and a logged-in GUI session.

| Layer | What it proves | Where |
|---|---|---|
| L0 | Facts duplicated across files still agree – uninstall paths, localized keys and their bundle spelling, the widget's option enums, the scheme/test-plan wiring and its safe-mode interlock, the manual's links and screenshot list | `scripts/check-*.sh` |
| L1 | Pure logic: calendar math, spoken labels, widget options, the `leapwidget://` relay, uninstall escaping, the timeline | `LeapCore/Tests/LeapCoreTests` |
| L2 | Properties measured off a render: full opacity, clipping, the today marker, the week-number footprint, six rows, RTL | `LayoutInvariantTests` |
| L3 | Golden snapshots – 24 PNGs, the change detector for anything nobody thought to assert | `SnapshotTests`, images under `LeapCore/Tests/LeapCoreTests/__Goldens__/<os>-<xcode>/` |
| L4 | The app through a real accessibility client: menus, the About panel, the uninstall alert, `performAccessibilityAudit` – and the `leapwidget://` relay a widget click sends, delivered as a real Apple Event | `LeapUITests`, driven by `Leap.xctestplan` |

```sh
make test                                                  # L0-L3
make report                                                # the same, plus reports/<stamp>-<hash>/
make snapshots-record                                      # regenerate goldens that moved
LEAP_SKIP_SNAPSHOTS=1 swift test --package-path LeapCore   # tightest loop
LEAP_BUDGETS=1 swift test --package-path LeapCore --filter BudgetTests

make ui-test                                               # L4, takes over the screen
make ui-test ONLY=LeapUITests/OnboardingUITests            # one class, or one test
```

`make ui-test` is what CI runs, so the local command and the merge gate cannot
drift. It leaves a result bundle at `build/LeapUITests.xcresult`; `open` it in
Xcode. Goldens are numbered so the 22 widget tiles sort ahead of the two
onboarding windows in `reports/*/screenshots/` and the contact sheet.

A golden diff means "look at this", not "this is wrong": inspect the expected,
actual and amplified-diff PNGs written to `reports/latest/screenshots/diff/`,
then fix the code or re-record. Goldens are committed *inputs*; everything
under `reports/` is a run's output and is git-ignored.

The UI tests move the mouse and take over the keyboard. Two of them reach
outside the test – the uninstall alert and the widget-click relay – and are
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
| `Leap/` | Host app: onboarding, `leapwidget://` → calendar URL relay |
| `LeapWidget/` | Widget extension: intent, timeline provider, widget declaration |
| `LeapCore/` | Local Swift package: calendar math, models, theming, widget options, the relay and the views – plus L0-L3 tests and the golden images |
| `LeapUITests/` | XCUITest target (L4), run through `Leap.xctestplan` |
| `docs/manual/` | The user manual in Markdown, plus its screenshots |
| `scripts/` | L0 consistency checks, the help-book build, the report harness and the release script |
| `packaging/` | The Homebrew cask's source of truth, seeded into the tap on first publish |

## License

TBD
