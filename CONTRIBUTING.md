# Contributing to Leap Widget

Issues and pull requests are welcome. Leap Widget is small on purpose, so a short
conversation before you write code saves everyone time. Please follow these
guidelines:

- **Create an issue first.** Before starting any work,
  [open an issue](https://github.com/antavik/Leap-widget/issues) that describes the
  problem or the feature you have in mind, so we can agree on the approach and avoid
  duplicated effort. Typo and documentation fixes can go straight to a pull request.
- **Fork the repository.** Once the approach is agreed, fork the repository and create
  a branch from `main` with a name related to the issue.
- **Keep the product's promises.** The README promises no calendar access, no network,
  no account, and no third-party dependencies. A change that breaks one of these is
  unlikely to be accepted, so raise it in the issue first.
- **Follow the coding standards.** Run `make lint`, which runs SwiftLint in strict mode.
  Change build settings in `Config/*.xcconfig` and `project.yml`, not in Xcode's
  build-settings UI, and keep widget parameters as `String` or `Bool`
  (`scripts/check-widget-options.sh` explains why).
- **Write tests.** Add tests for new features and bug fixes, and make sure `make test`
  passes. If a golden snapshot moves, inspect the diff before you re-record it. See
  [Testing](#testing).
- **Update the documentation.** If users will notice the change, update `README.md` and
  the [manual](#the-manual). If you change an uninstall path, update `README.md`, the
  `Makefile`, and `packaging/leap-widget.rb` too, because `make test` compares them.
- **Submit a pull request.** Open it against `main` and reference the issue it addresses.
  CI runs the tests on every pull request, and a maintainer will review your changes.
- **Be patient.** Reviews can take a while. Thank you for waiting, and for contributing.

By submitting a contribution, you agree that it is licensed under the project's
[MIT License](LICENSE).

## Requirements

- macOS, with Xcode to build. CI pins Xcode 26.3 and also runs the tests on Xcode 27.1.
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`) – the
  `.xcodeproj` is generated from `project.yml`, not committed.
- [SwiftLint](https://github.com/realm/SwiftLint) (`brew install swiftlint`), for
  `make lint`.

The app itself runs on macOS 14 Sonoma or later.

## Building

```sh
make test

make build
```

`make help` lists every target. `make lint` runs SwiftLint in strict mode
against `.swiftlint.yml` (`brew install swiftlint`).

`make build` and `make debug` regenerate the project first. Run `make project`
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

Local builds sign to run locally; only `make dist` signs with Developer ID.

On a development machine, `make uninstall` clears the paths listed in the README's
Uninstalling section for the copy in `/Applications`, deleting them outright rather than
moving them to the Trash.

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
| L3 | Golden snapshots – one PNG per case, the change detector for anything nobody thought to assert | `SnapshotTests`, images under `LeapCore/Tests/LeapCoreTests/__Goldens__/<os>-<xcode>/` |
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
Xcode. Goldens are numbered, so they keep a stable order in
`reports/*/screenshots/` and the contact sheet.

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
| `LeapWidgetTests/` | Unit tests for the widget extension's own code – intent → `CalendarSettings` mapping and the shipping widget view rendered from real intents – run through `Leap.xctestplan` |
| `LeapUITests/` | XCUITest target (L4), run through `Leap.xctestplan` |
| `Config/` | `.xcconfig` build settings: shared `Base`, per-configuration `Debug`/`Release`, and one per target |
| `docs/` | Documentation and its assets |
| `scripts/` | L0 consistency checks, the help-book build, the report harness and the release script |
| `packaging/` | The Homebrew cask's source of truth, seeded into the tap on first publish |
