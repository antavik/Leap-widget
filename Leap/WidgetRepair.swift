import AppKit
import CoreServices
import WidgetKit
import LeapCore

/// Live wiring for `WidgetRepairer`. Runs on the first launch of each build
/// and from Help ▸ Repair Widgets.
@MainActor
enum WidgetRepair {
    static func repairIfUpdated() async {
        await repairer.repairIfUpdated(build: BuildMarker.build(of: .main),
                                       marker: BuildMarker(key: Constants.Defaults.repairedBuild))
    }

    @discardableResult
    static func repair() async -> WidgetRepairer.Outcome {
        await repairer.repair()
    }

    private static var repairer: WidgetRepairer {
        WidgetRepairer(app: Bundle.main.bundleURL,
                       ownsWidget: ownsWidget,
                       isSafeMode: LaunchEnvironment.isUITestSafeMode,
                       system: .live)
    }

    /// Debug builds never own it: they rebuild constantly, and must not take
    /// the gallery over from the installed app.
    private static var ownsWidget: Bool {
#if DEBUG
        false
#else
        InstallLocation.ownsWidget(Bundle.main.bundleURL, home: .homeDirectory)
#endif
    }

    /// Off the main actor: LaunchServices blocks.
    @concurrent fileprivate nonisolated static func lsRegister(_ app: URL) async {
        LSRegisterURL(app as CFURL, true)
    }
}

private extension WidgetRepairer.System {
    static var live: Self {
        Self(
            registeredCopies: {
                NSWorkspace.shared.urlsForApplications(
                    withBundleIdentifier: Constants.Bundles.current)
            },
            unregister: { copy in
                await SystemTool.run("/usr/bin/pluginkit",
                                     ["-r", widget(in: copy)])
                await SystemTool.run(SystemTool.lsregister,
                                     ["-u", copy.path(percentEncoded: false)])
            },
            register: { app in
                await WidgetRepair.lsRegister(app)
                await SystemTool.run("/usr/bin/pluginkit",
                                     ["-a", widget(in: app)])
            },
            // Both relaunch on demand; widgets flicker once.
            restartHost: {
                await SystemTool.run("/usr/bin/killall", ["chronod", "NotificationCenter"]) == 0
            },
            reloadTimelines: {
                WidgetCenter.shared.reloadAllTimelines()
            })
    }

    private static func widget(in app: URL) -> String {
        Constants.Bundles.widgetExtension(in: app).path(percentEncoded: false)
    }
}
