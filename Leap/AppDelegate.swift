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
        NSApp.setActivationPolicy(.accessory)   // no Dock icon
        if relayedURL {
            NSApp.terminate(nil)
        } else {
            showMainWindow()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            showMainWindow()
            return false   // handled here – skip AppKit's default reopen pass
        }
        return true
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
        openCalendar(target: target(from: relay))
        if let window, window.isVisible {
            return   // app was already open with UI – keep it running
        }
        NSApp.terminate(nil)
    }

    /// What the clicked widget asked for, as encoded in the relay URL.
    private enum URLRelayTarget {
        /// `?action=<token>` or `?url=<something>` – open exactly this.
        case explicit(URL)
        /// `?url=` empty or rejected – open nothing.
        case doNothing
        /// Neither key, or an unknown preset token – a timeline from another
        /// app version; fall back to the default calendar.
        case unspecified
    }

    /// `leap://` is system-wide, so any process or consenting web page can
    /// invoke it. Never let it launder path-launching URLs: `NSWorkspace.open`
    /// would launch apps and files, not calendars.
    private static let blockedSchemes: Set<String> = ["file", "smb", "afp", "nfs", "ftp", "cifs"]

    /// Per-widget click target. Preset `action` tokens resolve only through
    /// `ClickPreset`, so the relay cannot name arbitrary URLs. `url` carries
    /// custom targets and pre-token timelines, filtered by scheme.
    private func target(from relay: URL) -> URLRelayTarget {
        guard let components = URLComponents(url: relay, resolvingAgainstBaseURL: false)
        else { return .unspecified }

        let items = components.queryItems ?? []

        if let token = items.first(where: { $0.name == "action" })?.value {
            guard let preset = ClickPreset(rawValue: token),
                  let url = URL(string: preset.url)
            else { return .unspecified }
            return .explicit(url)
        }

        guard let item = items.first(where: { $0.name == "url" })
        else { return .unspecified }

        guard let value = item.value, !value.isEmpty, let url = URL(string: value),
              let scheme = url.scheme?.lowercased(),
              !Self.blockedSchemes.contains(scheme)
        else { return .doNothing }

        return .explicit(url)
    }

    private func openCalendar(target: URLRelayTarget) {
        switch target {
        case .doNothing:
            return
        case .explicit(let url):
            if NSWorkspace.shared.open(url) {
                return
            }
        case .unspecified:
            if let url = URL(string: "ical://"), NSWorkspace.shared.open(url) {
                return
            }
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
        let editItem: NSMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")

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

        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All",
                         action: #selector(NSText.selectAll(_:)),
                         keyEquivalent: "a")

        editItem.submenu = editMenu
        mainMenu.addItem(editItem)

        NSApp.mainMenu = mainMenu
    }
}
