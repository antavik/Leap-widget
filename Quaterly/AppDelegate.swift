import AppKit
import SwiftUI
import QuaterlyCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var relayedURL = false
    private var window: NSWindow?

    func applicationWillFinishLaunching(_ notification: Notification) {
        // Registering here (not in didFinishLaunching) guarantees a launch-by-URL
        // delivers the event before didFinishLaunching decides whether to show UI.
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleGetURL(_:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL))
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)   // no Dock icon (§4.1)
        if relayedURL {
            // Widget-click relay launch: no UI, hand off and exit (§4.9, §4.11).
            NSApp.terminate(nil)
        } else {
            showMainWindow()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            showMainWindow()
        }
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true   // §4.11: closing the window leaves no resident process
    }

    // MARK: - URL relay (§4.9)

    @objc private func handleGetURL(_ event: NSAppleEventDescriptor,
                                    withReplyEvent reply: NSAppleEventDescriptor) {
        guard let urlString = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue,
              let url = URL(string: urlString) else { return }
        handle(urls: [url])
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        handle(urls: urls)
    }

    private func handle(urls: [URL]) {
        guard urls.contains(where: { $0.host == "open-calendar" }) else { return }
        relayedURL = true
        openDefaultCalendar()
        if let window, window.isVisible {
            return   // app was already open with UI — keep it running
        }
        NSApp.terminate(nil)
    }

    private func openDefaultCalendar() {
        let scheme = QuaterlySettings.launchCalendarScheme   // §4.8; default "ical://"
        if let url = URL(string: scheme), NSWorkspace.shared.open(url) {
            return   // Launch Services → user's default calendar app
        }
        // Fallback: open Apple Calendar directly (§4.9).
        if let calendarApp = NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: "com.apple.iCal") {
            NSWorkspace.shared.openApplication(at: calendarApp,
                                               configuration: NSWorkspace.OpenConfiguration())
        }
    }

    // MARK: - Window

    private func showMainWindow() {
        if let window {
            window.makeKeyAndOrderFront(nil)
        } else {
            let hosting = NSHostingController(rootView: MainView())
            let newWindow = NSWindow(contentViewController: hosting)
            newWindow.title = "Quaterly"
            newWindow.styleMask = [.titled, .closable, .miniaturizable]
            newWindow.isReleasedWhenClosed = false
            newWindow.center()
            newWindow.makeKeyAndOrderFront(nil)
            window = newWindow
        }
        NSApp.activate(ignoringOtherApps: true)
    }
}
