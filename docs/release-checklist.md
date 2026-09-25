# Release checklist

What no automated layer can reach. Each item names why, so it can leave this
list the day a test can reach it.

Run on the release build, installed in `/Applications`, with both widgets
placed on the desktop.

## Widget configuration

- [ ] **An edit re-renders the placed widget.** For each widget, open *Edit
      Widget* and change every parameter once. The widget redraws within a few
      seconds, showing what the matching golden shows.
      *Why manual:* WidgetKit renders the placed widget in another process and
      decides when to reload it. Every link before that – intent → settings →
      entry → pixels – is tested: `LeapWidgetTests` and
      `ConfigurationChangeTests`.
- [ ] **"Click Opens: Nothing" gives no press feedback.** Press and hold on the
      widget: it neither dims nor highlights.
      *Why manual:* `WidgetViewRenderTests` pins the idle pixels only; the
      pressed state exists only under a real click.

## Clicking the widget

- [ ] **Each click action opens its calendar** – Default Calendar, Fantastical,
      Google Calendar – and "Nothing" opens nothing.
      *Why manual:* that `widgetURL` is attached at all is only visible to the
      host; `CalendarRelayUITests` covers the app's side of the click.
- [ ] **A click with Leap not running opens the calendar and Leap quits.**
      *Why manual:* a sandboxed test runner cannot arm safe mode on a cold
      launch – see `CalendarRelayUITests`.

## Onboarding

- [ ] **The donation row's links show their text and accent colour, and open.**
      *Why manual:* `ImageRenderer` draws `Link` as a placeholder – see
      `GoldenCase.onboardingCases`.
