import CoreServices
import Foundation

/// Opening an app does not reliably register its widget extension: a bundle
/// replaced in place keeps its stale LaunchServices record, and the gallery
/// stays empty. Registering on launch fixes that without a trip to Terminal.
enum WidgetRegistration {
    static func register() async {
#if !DEBUG
        // Debug builds must never take over the gallery from the installed app.
        let app = Bundle.main.bundleURL
        let widget = app.appending(components: "Contents", "PlugIns", "LeapWidget.appex")

        await Task.detached(priority: .utility) {
            LSRegisterURL(app as CFURL, true)

            let pluginkit = Process()
            pluginkit.executableURL = URL(filePath: "/usr/bin/pluginkit")
            pluginkit.arguments = ["-a", widget.path(percentEncoded: false)]
            pluginkit.standardOutput = FileHandle.nullDevice
            pluginkit.standardError = FileHandle.nullDevice
            try? pluginkit.run()
            pluginkit.waitUntilExit()
        }.value
#endif
    }
}
