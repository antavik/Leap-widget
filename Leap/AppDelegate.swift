import AppKit
import SwiftUI
import LeapCore

@MainActor
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
        buildMainMenu()
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if relayedURL {
            NSApp.terminate(nil)
        } else {
            showMainWindow()
        }
    }

    // MARK: - URL relay

    @objc private func handleGetURL(_ event: NSAppleEventDescriptor,
                                    withReplyEvent reply: NSAppleEventDescriptor) {
        guard let urlString = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue,
              let url = URL(string: urlString) else { return }
        handle(urls: [url])
    }

    private func handle(urls: [URL]) {
        guard let relay = urls.first(where: { $0.host == "open-calendar" }) else { return }
        relayedURL = true
        openCalendar(presetURL(from: relay))
    }

    /// `leap://` is system-wide, so any process or consenting web page can
    /// invoke it. It therefore names calendars only by opaque `ClickPreset`
    /// token: every URL that can reach `NSWorkspace` is a fixed string
    /// compiled in here, never one the caller supplied. `nil` means the token
    /// was missing or unknown — a timeline from another app version.
    private func presetURL(from relay: URL) -> URL? {
        guard let components = URLComponents(url: relay, resolvingAgainstBaseURL: false),
              let token = components.queryItems?.first(where: { $0.name == "action" })?.value,
              let preset = ClickPreset(rawValue: token)
        else { return nil }

        return URL(string: preset.url)
    }

    private func openCalendar(_ url: URL?) {
        // An unrecognised relay falls back to the default calendar.
        if let target = url ?? URL(string: "ical://"), NSWorkspace.shared.open(target) {
            return
        }

        if let calendarApp = NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: "com.apple.iCal") {
            NSWorkspace.shared.openApplication(at: calendarApp,
                                               configuration: NSWorkspace.OpenConfiguration())
        }
    }

    // MARK: - Window

    private static let windowFrameAutosaveName = NSWindow.FrameAutosaveName("LeapMainWindow")

    private func showMainWindow() {
        NSApp.setActivationPolicy(.regular)
        let window = self.window ?? {
            let hosting = NSHostingController(rootView: MainView())
            let newWindow = NSWindow(contentViewController: hosting)
            newWindow.title = "Leap"
            newWindow.styleMask = [.titled, .closable]
            newWindow.isReleasedWhenClosed = false
            if !newWindow.setFrameUsingName(Self.windowFrameAutosaveName) {
                newWindow.center()
            }
            newWindow.setFrameAutosaveName(Self.windowFrameAutosaveName)
            self.window = newWindow
            return newWindow
        }()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    // MARK: - Menu

    private func buildMainMenu() {
        let mainMenu = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        let fileItem = NSMenuItem()
        let fileMenu = NSMenu(title: "File")

        appMenu.addItem(withTitle: "About Leap",
                        action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)),
                        keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit Leap",
                        action: #selector(NSApplication.terminate(_:)),
                        keyEquivalent: "q")

        appItem.submenu = appMenu
        mainMenu.addItem(appItem)

        fileMenu.addItem(withTitle: "Close Window",
                         action: #selector(NSWindow.performClose(_:)),
                         keyEquivalent: "w")

        fileItem.submenu = fileMenu
        mainMenu.addItem(fileItem)

        // No Edit menu: the onboarding window holds no editable text.
        NSApp.mainMenu = mainMenu
    }
}
