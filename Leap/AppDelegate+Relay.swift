import AppKit
import LeapCore

extension AppDelegate {
    @objc func handleGetURL(_ event: NSAppleEventDescriptor,
                            withReplyEvent reply: NSAppleEventDescriptor) {
        guard let urlString = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue,
              let url = URL(string: urlString),
              CalendarRelay.isRelay(url)
        else { return }

        relayedURL = true
        openCalendar(CalendarRelay.target(forRelay: url))
    }

    private func openCalendar(_ url: URL?) {
        // An unrecognised relay falls back to the default calendar.
        let target = url ?? URL(string: "ical://")

        if let record = LaunchEnvironment.relayRecordURL {
            try? (target?.absoluteString ?? "none")
                .appending("\n")
                .write(to: record, atomically: true, encoding: .utf8)
            return
        }

        if let target, NSWorkspace.shared.open(target) {
            return
        }

        if let calendarApp = NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: Constants.Bundles.appleCalendar) {
            NSWorkspace.shared.openApplication(at: calendarApp,
                                               configuration: NSWorkspace.OpenConfiguration())
        }
    }
}
