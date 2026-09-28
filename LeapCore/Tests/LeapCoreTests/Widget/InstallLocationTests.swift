import Testing
import Foundation
@testable import LeapCore

@Suite("Install location")
struct InstallLocationTests {
    private let home = URL(filePath: "/Users/me", directoryHint: .isDirectory)

    @Test(arguments: [
        "/Applications/Leap.app",
        "/Applications/Utilities/Leap.app",
        "/Users/me/Applications/Leap.app"
    ])
    func anApplicationsFolderOwnsTheWidget(path: String) {
        #expect(InstallLocation.ownsWidget(URL(filePath: path), home: home))
    }

    @Test(arguments: [
        "/Users/me/Downloads/Leap.app",
        "/Users/me/.Trash/Leap.app",
        "/Volumes/My Shared Files/macos/Leap.app",
        "/Volumes/Leap/Applications/Leap.app",
        "/Users/me/Repos/Leap/build/Build/Products/Release/Leap.app",
        "/ApplicationsOld/Leap.app",
        "/Users/other/Applications/Leap.app"
    ])
    func anyOtherFolderDoesNot(path: String) {
        #expect(!InstallLocation.ownsWidget(URL(filePath: path), home: home))
    }

    @Test func aTranslocatedCopyDoesNot() {
        let translocated = URL(filePath:
            "/private/var/folders/_l/m9k/T/AppTranslocation/0F1E2D3C/d/Applications/Leap.app")

        #expect(!InstallLocation.ownsWidget(translocated, home: home))
    }

    @Test func theBundleURLsTrailingSlashDoesNotMatter() {
        let slashed = URL(filePath: "/Applications/Leap.app", directoryHint: .isDirectory)

        #expect(InstallLocation.ownsWidget(slashed, home: home))
    }
}
