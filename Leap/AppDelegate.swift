import AppKit
import LeapCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    var relayedURL = false
    var isUninstalling = false
    var window: NSWindow?
#if DEBUG
    var previewWindow: NSWindow?
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
            // A click on a broken widget should repair it too.
            Task {
                await WidgetRepair.repairIfUpdated()
                NSApp.terminate(nil)
            }
            return
        }

        buildMainMenu()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersDidChange(_:)),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil)

        // Repairs on the first launch of a new build only.
        Task {
            await WidgetRepair.repairIfUpdated()
        }

        showMainWindow()
    }
}
