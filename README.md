# Leap

A macOS calendar widget for the Desktop and Notification Center, visually matching
Apple's built-in Calendar month widget. Shows the current month plus a configurable
neighbor; follows the system light/dark appearance; clicking a widget opens your
default calendar application.

100 % native — Swift, SwiftUI, WidgetKit, AppKit. Zero third-party dependencies.

## Requirements

- macOS 14 Sonoma or later (Desktop widgets, per-widget configuration)
- Xcode 16+ to build

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
# Unit tests (calendar math, rendering, performance)
swift test --package-path LeapCore

# App + widget extension
xcodebuild -project Leap.xcodeproj -scheme Leap -configuration Release build
```

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

## Project layout

| Path | Contents |
|---|---|
| `Leap/` | Host app: onboarding, `leap://` → calendar URL relay |
| `LeapWidget/` | Widget extension: intent, timeline provider, widget declaration |
| `LeapCore/` | Local Swift package: calendar math, models, theming, month views + all unit tests |

## License

TBD
