import AppKit
import SwiftUI
import WidgetKit
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
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard !relayedURL else {
            NSApp.terminate(nil)
            return
        }

        buildMainMenu()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersDidChange(_:)),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil)

        // Up to 0.1.0 the window frame was autosaved under this key. Placement
        // is computed on every open now, so the leftover is dead weight in the
        // container defaults. Drop this call once 0.1.0 is out of circulation.
        UserDefaults.standard.removeObject(forKey: "NSWindow Frame LeapMainWindow")

        // Reload on every launch that shows UI so chronod rebuilds archives for
        // the environments in use now. Otherwise a gallery-added widget can get
        // stuck on its placeholder with "no matching environment".
        WidgetCenter.shared.reloadAllTimelines()

        showMainWindow()
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

    /// `leap://` is system-wide, so only known `ClickPreset` tokens map to
    /// calendar URLs. `nil` means the token was missing or unknown.
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
            withBundleIdentifier: Constants.Bundles.appleCalendar) {
            NSWorkspace.shared.openApplication(at: calendarApp,
                                               configuration: NSWorkspace.OpenConfiguration())
        }
    }

    // MARK: - Window

    private func showMainWindow() {
        if NSApp.activationPolicy() != .regular {
            NSApp.setActivationPolicy(.regular)
        }

        let window = self.window ?? {
            let created = makeMainWindow()
            self.window = created
            return created
        }()

        if !window.isVisible {
            center(window, on: currentScreens())
        }

        window.makeKeyAndOrderFront(nil)

        NSApp.activate(ignoringOtherApps: true)
    }

    private func makeMainWindow() -> NSWindow {
        let hosting = NSHostingController(rootView: MainView())
        let window = NSWindow(contentViewController: hosting)
        window.title = "Leap"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false

        window.isRestorable = false

        hosting.view.layoutSubtreeIfNeeded()
        window.setContentSize(hosting.view.fittingSize)

        return window
    }

    private func center(_ window: NSWindow, on screens: [ScreenGeometry]) {
        guard let visibleFrame = WindowPlacement.activeVisibleFrame(
            mouseLocation: NSEvent.mouseLocation,
            screens: screens,
            mainScreen: NSScreen.main.map(ScreenGeometry.init))
        else {
            window.center()
            return
        }

        window.setFrameOrigin(
            WindowPlacement.centeredOrigin(for: window.frame.size, in: visibleFrame))
    }

    private func currentScreens() -> [ScreenGeometry] {
        NSScreen.screens.map(ScreenGeometry.init)
    }

    @objc private func screenParametersDidChange(_ notification: Notification) {
        guard let window, window.isVisible else { return }

        let screens = currentScreens()
        guard !WindowPlacement.isOnScreen(window.frame, screens: screens) else { return }

        center(window, on: screens)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication,
                                       hasVisibleWindows: Bool) -> Bool {
        showMainWindow()

        WidgetCenter.shared.reloadAllTimelines()

        return true
    }

    // MARK: - Menu

    private func buildMainMenu() {
        let mainMenu = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        let fileItem = NSMenuItem()
        let fileMenu = NSMenu(title: "File")
        let helpItem = NSMenuItem()
        let helpMenu = NSMenu(title: "Help")

        appMenu.addItem(withTitle: "About Leap",
                        action: #selector(showAboutPanel),
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

        helpMenu.addItem(withTitle: "Donate…",
                         action: #selector(openDonationPage),
                         keyEquivalent: "")

        helpItem.submenu = helpMenu
        mainMenu.addItem(helpItem)

        // No Edit menu: the onboarding window holds no editable text.
        NSApp.mainMenu = mainMenu
        // Marks the menu as the Help menu so macOS files it last and adds its
        // own search item.
        NSApp.helpMenu = helpMenu
    }

    @objc private func openDonationPage() {
        NSWorkspace.shared.open(Constants.Links.donation)
    }

    @objc private func showAboutPanel() {
        let info = Bundle.main.infoDictionary
        var options: [NSApplication.AboutPanelOptionKey: Any] = [:]
        if let marketing = info?["CFBundleShortVersionString"] as? String {
            options[.applicationVersion] = marketing
        }
        if let commit = info?["LeapBuildCommit"] as? String, !commit.isEmpty {
            options[.version] = commit
        }
        options[.credits] = NSAttributedString(
            string: "Created by Antavik",
            attributes: [
                .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
                .foregroundColor: NSColor.labelColor,
                .paragraphStyle: centeredParagraphStyle
            ])
        NSApp.activate()
        NSApp.orderFrontStandardAboutPanel(options: options)
    }

    private var centeredParagraphStyle: NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        return style
    }
}

private extension ScreenGeometry {
    init(_ screen: NSScreen) {
        self.init(frame: screen.frame, visibleFrame: screen.visibleFrame)
    }
}
