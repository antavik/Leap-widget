import Testing
import Foundation
@testable import LeapCore

/// The order matters: a stray copy still registered when the host restarts
/// gets matched against the extension, and its renders are rejected.
@MainActor
@Suite("Widget repair")
struct WidgetRepairerTests {
    private let installed = URL(filePath: "/Applications/Leap.app")
    private let stray = URL(filePath: "/Users/tester/Downloads/Leap.app")

    /// Records every system call in order.
    @MainActor
    private final class Recorder {
        var calls: [String] = []
        var restartSucceeds = true
    }

    private func repairer(_ recorder: Recorder,
                          ownsWidget: Bool = true,
                          isSafeMode: Bool = false) -> WidgetRepairer {
        WidgetRepairer(
            app: installed,
            ownsWidget: ownsWidget,
            isSafeMode: isSafeMode,
            system: WidgetRepairer.System(
                registeredCopies: { [installed, stray] in [stray, installed] },
                unregister: { recorder.calls.append("unregister \($0.path(percentEncoded: false))") },
                register: { recorder.calls.append("register \($0.path(percentEncoded: false))") },
                restartHost: {
                    recorder.calls.append("restart")
                    return recorder.restartSucceeds
                },
                reloadTimelines: { recorder.calls.append("reload") }))
    }

    /// Not `.standard`: that is the app's real domain.
    private func marker() -> (BuildMarker, UserDefaults, String) {
        let defaults = UserDefaults(suiteName: "com.antavik.leapwidget.tests")!
        let key = "repaired.\(UUID().uuidString)"

        return (BuildMarker(defaults: defaults, key: key), defaults, key)
    }

    // MARK: - Repair

    @Test func unregistersStraysThenRegistersThenRestartsThenReloads() async {
        let recorder = Recorder()

        #expect(await repairer(recorder).repair() == .repaired)
        #expect(recorder.calls == [
            "unregister /Users/tester/Downloads/Leap.app",
            "register /Applications/Leap.app",
            "restart",
            "reload"
        ])
    }

    @Test func aCopyThatDoesNotOwnTheWidgetOnlyRestarts() async {
        let recorder = Recorder()

        #expect(await repairer(recorder, ownsWidget: false).repair() == .repaired)
        #expect(recorder.calls == ["restart", "reload"])
    }

    @Test func safeModeTouchesNothing() async {
        let recorder = Recorder()

        #expect(await repairer(recorder, isSafeMode: true).repair() == .skipped)
        #expect(recorder.calls.isEmpty)
    }

    @Test func aFailedRestartSkipsTheReload() async {
        let recorder = Recorder()
        recorder.restartSucceeds = false

        #expect(await repairer(recorder).repair() == .hostRestartFailed)
        #expect(recorder.calls.last == "restart")
    }

    // MARK: - First launch of a build

    @Test func aNewBuildRepairsOnceAndIsMarked() async {
        let (marker, defaults, key) = self.marker()
        defer { defaults.removeObject(forKey: key) }
        let recorder = Recorder()
        let repairer = repairer(recorder)

        await repairer.repairIfUpdated(build: "0.2.26 (1)", marker: marker)
        await repairer.repairIfUpdated(build: "0.2.26 (1)", marker: marker)

        #expect(recorder.calls.filter { $0 == "restart" }.count == 1)
        #expect(!marker.isBehind("0.2.26 (1)"))
    }

    @Test func aFailedRepairLeavesTheBuildUnmarkedSoItRetries() async {
        let (marker, defaults, key) = self.marker()
        defer { defaults.removeObject(forKey: key) }
        let recorder = Recorder()
        recorder.restartSucceeds = false

        await repairer(recorder).repairIfUpdated(build: "0.2.26 (1)", marker: marker)

        #expect(marker.isBehind("0.2.26 (1)"))
    }

    @Test(arguments: [(false, false), (true, true)])
    func neitherAForeignCopyNorSafeModeRepairsOnUpdate(ownsWidget: Bool, isSafeMode: Bool) async {
        let (marker, defaults, key) = self.marker()
        defer { defaults.removeObject(forKey: key) }
        let recorder = Recorder()

        await repairer(recorder, ownsWidget: ownsWidget, isSafeMode: isSafeMode)
            .repairIfUpdated(build: "0.2.26 (1)", marker: marker)

        #expect(recorder.calls.isEmpty)
        #expect(marker.isBehind("0.2.26 (1)"))
    }
}
