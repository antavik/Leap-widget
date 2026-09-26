import AppKit
import SwiftUI
import WidgetKit
import LeapCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var relayedURL = false
    var isUninstalling = false
    private var window: NSWindow?
#if DEBUG
    private var previewWindow: NSWindow?
#endif

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

        // Reload on every launch that shows UI so chronod rebuilds archives for
        // the environments in use now. Otherwise a gallery-added widget can get
        // stuck on its placeholder with "no matching environment".
        Task {
            await WidgetRegistration.register()
            WidgetCenter.shared.reloadAllTimelines()
        }

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
        guard let relay = urls.first(where: CalendarRelay.isRelay) else { return }
        relayedURL = true
        openCalendar(CalendarRelay.target(forRelay: relay))
    }

    static var relayRecordURL: URL? {
        guard isUITestSafeMode,
              let path = ProcessInfo.processInfo.environment["LEAP_UI_TEST_RELAY_RECORD"]
        else { return nil }

        return URL(filePath: path)
    }

    private func openCalendar(_ url: URL?) {
        // An unrecognised relay falls back to the default calendar.
        let target = url ?? URL(string: "ical://")

        if let record = Self.relayRecordURL {
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

        activate()
    }

    /// `NSApp.activate()` can be denied on macOS 14+; retry as if the
    /// frontmost app handed over focus.
    private func activate() {
        NSApp.activate()

        guard !NSApp.isActive,
              let frontmost = NSWorkspace.shared.frontmostApplication,
              frontmost != .current
        else { return }

        NSRunningApplication.current.activate(from: frontmost)
    }

    private func makeMainWindow() -> NSWindow {
        let hosting = NSHostingController(rootView: MainView())
        hosting.sizingOptions = [.preferredContentSize]

        let window = NSWindow(contentViewController: hosting)
        window.title = String(localized: "Leap", comment: "Main window title")
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false

        window.isRestorable = false

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
        let fileMenu = NSMenu(title: String(localized: "File", comment: "Menu bar title"))
        let helpItem = NSMenuItem()
        let helpMenu = NSMenu(title: String(localized: "Help", comment: "Menu bar title"))

        appMenu.addItem(withTitle: String(localized: "About Leap", comment: "App menu item"),
                        action: #selector(showAboutPanel),
                        keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: String(localized: "Quit Leap", comment: "App menu item"),
                        action: #selector(NSApplication.terminate(_:)),
                        keyEquivalent: "q")

        appItem.submenu = appMenu
        mainMenu.addItem(appItem)

        fileMenu.addItem(withTitle: String(localized: "Close Window", comment: "File menu item"),
                         action: #selector(NSWindow.performClose(_:)),
                         keyEquivalent: "w")

        fileItem.submenu = fileMenu
        mainMenu.addItem(fileItem)

#if DEBUG
        let debugItem = NSMenuItem()
        let debugMenu = NSMenu(title: "Debug")
        debugMenu.addItem(withTitle: "Accessibility Preview",
                          action: #selector(showAccessibilityPreview),
                          keyEquivalent: "")
        debugItem.submenu = debugMenu
        mainMenu.addItem(debugItem)
#endif

        helpMenu.addItem(withTitle: String(localized: "Leap Manual", comment: "Help menu item"),
                         action: #selector(NSApplication.showHelp(_:)),
                         keyEquivalent: "?")
        helpMenu.addItem(.separator())
        helpMenu.addItem(withTitle: String(localized: "Support & Feedback", comment: "Help menu item"),
                         action: #selector(openSupportMail),
                         keyEquivalent: "")
        helpMenu.addItem(withTitle: String(localized: "Donate", comment: "Help menu item"),
                         action: #selector(openDonationPage),
                         keyEquivalent: "")
        helpMenu.addItem(.separator())
        helpMenu.addItem(withTitle: String(localized: "Uninstall Leap…", comment: "Help menu item"),
                         action: #selector(confirmUninstall),
                         keyEquivalent: "")

        helpItem.submenu = helpMenu
        mainMenu.addItem(helpItem)

        NSApp.mainMenu = mainMenu
        NSApp.helpMenu = helpMenu
    }

    @objc private func openDonationPage() {
        NSWorkspace.shared.open(Constants.Links.donation)
    }

    @objc private func openSupportMail() {
        NSWorkspace.shared.open(Constants.Mail.support)
    }

#if DEBUG
    // MARK: - Accessibility preview

    /// A placed widget is drawn by WidgetKit in another process, so the
    /// Inspector never attaches to the app you built. This hosts the same view
    /// in-process, where its accessibility tree can be walked.
    @objc private func showAccessibilityPreview() {
        let window = previewWindow ?? makeAccessibilityPreviewWindow()
        previewWindow = window

        window.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    private func makeAccessibilityPreviewWindow() -> NSWindow {
        let row = monthRow(containing: .now,
                           offsets: [0, 1],
                           showYear: true,
                           builder: MonthModelBuilder(
                               calendar: .autoupdatingCurrent,
                               options: MonthOptions(showWeekNumbers: true)))
        // The medium widget's tile, so the grid lays out as it ships.
        let hosting = NSHostingController(
            rootView: CalendarSurface(models: row.models, yearLabel: row.yearLabel)
                .frame(width: WidgetGeometry.medium.tileSize.width,
                       height: WidgetGeometry.medium.tileSize.height))
        hosting.sizingOptions = [.preferredContentSize]

        let window = NSWindow(contentViewController: hosting)
        window.title = "Accessibility Preview"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false
        window.center()

        return window
    }
#endif

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
            string: String(localized: "Created by Antavik", comment: "About panel credits"),
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
