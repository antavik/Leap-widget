import Testing
import Foundation
@testable import LeapCore

@Suite("Stray copies")
struct StrayCopiesTests {
    private let installed = URL(filePath: "/Applications/Leap.app", directoryHint: .isDirectory)

    @Test func theRunningCopyIsNeverAStray() {
        #expect(StrayCopies.among([installed], running: installed).isEmpty)
    }

    @Test func everyOtherCopyIsAStray() {
        let trashed = URL(filePath: "/Users/me/.Trash/Leap 10-38-03-749.app")
        let shared = URL(filePath: "/Volumes/My Shared Files/macos/Leap.app")

        let strays = StrayCopies.among([trashed, installed, shared], running: installed)

        #expect(strays == [trashed, shared])
    }

    @Test func aTrailingSlashIsTheSameCopy() {
        let unslashed = URL(filePath: "/Applications/Leap.app", directoryHint: .notDirectory)

        #expect(StrayCopies.among([installed], running: unslashed).isEmpty)
        #expect(StrayCopies.among([unslashed], running: installed).isEmpty)
    }

    @Test func aCopyListedTwiceIsDroppedOnce() {
        let build = URL(filePath: "/Users/me/Repos/Leap/build/Release/Leap.app")

        #expect(StrayCopies.among([build, build], running: installed) == [build])
    }
}
