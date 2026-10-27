import AppKit
import SwiftUI
import WidgetKit
import LeapCore

extension AppDelegate {
    func showMainWindow() {
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

    @objc func screenParametersDidChange(_ notification: Notification) {
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
}

private extension ScreenGeometry {
    init(_ screen: NSScreen) {
        self.init(frame: screen.frame, visibleFrame: screen.visibleFrame)
    }
}
