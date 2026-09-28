import Testing
import Foundation
@testable import LeapCore

/// The marker decides whether an update asks the host to rebuild what it
/// cached. Firing twice would reload widgets for nothing; not firing leaves a
/// placeholder on the Desktop until the archive goes stale.
@Suite("Build marker")
struct BuildMarkerTests {
    /// A suite of its own per test: `UserDefaults.standard` is the app's real
    /// container, and these write.
    private func marker() -> (BuildMarker, UserDefaults, String) {
        let name = "leap.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!

        return (BuildMarker(defaults: defaults), defaults, name)
    }

    @Test func aFreshInstallAdvances() {
        let (marker, defaults, name) = self.marker()
        defer { defaults.removePersistentDomain(forName: name) }

        #expect(marker.advance(to: "0.2.4 (1)"))
    }

    @Test func theSameBuildAdvancesOnlyOnce() {
        let (marker, defaults, name) = self.marker()
        defer { defaults.removePersistentDomain(forName: name) }

        #expect(marker.advance(to: "0.2.4 (1)"))
        #expect(!marker.advance(to: "0.2.4 (1)"))
        #expect(!marker.advance(to: "0.2.4 (1)"))
    }

    /// The build number moves on every build, the marketing version only on a
    /// release: either one is an update as far as the host's archives go.
    @Test(arguments: ["0.2.4 (2)", "0.2.5 (1)"])
    func anyPartOfTheBuildAdvancing(next: String) {
        let (marker, defaults, name) = self.marker()
        defer { defaults.removePersistentDomain(forName: name) }

        #expect(marker.advance(to: "0.2.4 (1)"))
        #expect(marker.advance(to: next))
        #expect(!marker.advance(to: next))
    }

    @Test func askingDoesNotRecord() {
        let (marker, defaults, name) = self.marker()
        defer { defaults.removePersistentDomain(forName: name) }

        #expect(marker.isBehind("0.2.4 (1)"))
        #expect(marker.isBehind("0.2.4 (1)"))
        #expect(marker.advance(to: "0.2.4 (1)"))
        #expect(!marker.isBehind("0.2.4 (1)"))
        #expect(marker.isBehind("0.2.4 (2)"))
    }

    @Test func theBuildJoinsVersionAndNumber() throws {
        let root = URL.temporaryDirectory.appending(component: "leap.tests.\(UUID().uuidString).bundle")
        let contents = root.appending(component: "Contents")
        defer { try? FileManager.default.removeItem(at: root) }

        try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
        let info: [String: Any] = ["CFBundleIdentifier": "com.antavik.leap.tests",
                                   "CFBundleShortVersionString": "0.2.19",
                                   "CFBundleVersion": "1790573081"]
        try PropertyListSerialization
            .data(fromPropertyList: info, format: .xml, options: 0)
            .write(to: contents.appending(component: "Info.plist"))

        let bundle = try #require(Bundle(url: root))

        #expect(BuildMarker.build(of: bundle) == "0.2.19 (1790573081)")
    }
}
