# Quaterly

A macOS calendar widget for the Desktop and Notification Center, visually matching
Apple's built-in Calendar month widget. Shows one, two, or three months per widget
instance; follows the system light/dark appearance; clicking a widget opens your
default calendar application.

100 % native — Swift, SwiftUI, WidgetKit, AppKit. Zero third-party dependencies.

## Requirements

- macOS 14 Sonoma or later (Desktop widgets, per-widget configuration)
- macOS 15+ additionally offers the extra-large widget size
- Xcode 16+ to build

## Features

- **1, 2, or 3 months** per widget: current only; current + previous *or* next;
  previous + current + next
- **Desktop and Notification Center** placement, in every widget size
- **Light/dark** follows macOS automatically, including the faded Desktop style
- **Week numbers** (optional) — ISO-8601 in Monday-first layouts, regional otherwise
- **First day of week** — system default or any explicit weekday
- **Click → your default calendar app** — respects Fantastical/BusyCal via the
  `ical://` handler, configurable in the app
- No events shown, no EventKit — **no privacy prompts, no network**

## Building

```sh
# Unit tests (calendar math, rendering, performance)
swift test --package-path QuaterlyCore

# App + widget extension
xcodebuild -project Quaterly.xcodeproj -scheme Quaterly -configuration Release build
```

Before signing for distribution, set your development team on both targets; the
App Group (`$(TeamIdentifierPrefix)com.antavik.quaterly`) picks up the team
automatically, and `AppGroup.identifier` in `QuaterlyCore/Sources/QuaterlyCore/AppGroup.swift`
must be updated to the same literal value.

## Using

1. Launch Quaterly once — that registers the widget with macOS.
2. Right-click the Desktop → **Edit Widgets…** → search “Quaterly” → drag the
   Calendar widget out (or add it from Notification Center's **Edit Widgets**).
3. Right-click the placed widget → **Edit “Calendar”** to choose the month span,
   first day of week, and week numbers.

The app's window guides you through these steps and confirms with “Widget added ✓”
when it detects the first placed widget. The app doesn't stay running — widgets are
rendered by the system.

## Project layout

| Path | Contents |
|---|---|
| `Quaterly/` | Host app: onboarding, settings, `quaterly://` → `ical://` URL relay |
| `QuaterlyWidget/` | Widget extension: intent, timeline provider, widget declaration |
| `QuaterlyCore/` | Local Swift package: calendar math, models, theming, month views + all unit tests |
| `DESIGN.md` | Full design document |
| `TODO.md` | Implementation checklist |

## License

TBD
