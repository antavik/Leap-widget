import Testing
import Foundation
@testable import LeapCore

private let home = URL(filePath: "/Users/tester")
private let bundle = URL(filePath: "/Applications/Leap.app")

/// Stands in for the filesystem: only the listed paths exist.
private func probe(_ present: String...) -> (URL) -> Bool {
    let present = Set(present)
    return { present.contains($0.path(percentEncoded: false)) }
}

// MARK: - Channel detection

@Test func detectsHomebrewOnAppleSilicon() {
    let channel = Uninstall.channel(
        exists: probe("/opt/homebrew/Caskroom/leap", "/opt/homebrew/bin/brew"))

    #expect(channel == .homebrew(brew: URL(filePath: "/opt/homebrew/bin/brew")))
}

@Test func detectsHomebrewOnIntel() {
    let channel = Uninstall.channel(
        exists: probe("/usr/local/Caskroom/leap", "/usr/local/bin/brew"))

    #expect(channel == .homebrew(brew: URL(filePath: "/usr/local/bin/brew")))
}

@Test func prefersAppleSiliconWhenBothPrefixesAreInstalled() {
    let channel = Uninstall.channel(
        exists: probe("/opt/homebrew/Caskroom/leap", "/opt/homebrew/bin/brew",
                      "/usr/local/Caskroom/leap", "/usr/local/bin/brew"))

    #expect(channel == .homebrew(brew: URL(filePath: "/opt/homebrew/bin/brew")))
}

@Test func treatsAnUnmanagedInstallAsDirect() {
    // Homebrew is installed, but it never installed Leap.
    #expect(Uninstall.channel(exists: probe("/opt/homebrew/bin/brew")) == .direct)
    #expect(Uninstall.channel(exists: probe()) == .direct)
}

@Test func treatsAReceiptWithoutBrewAsDirect() {
    #expect(Uninstall.channel(exists: probe("/opt/homebrew/Caskroom/leap")) == .direct)
}

// MARK: - Removal paths

@Test func removesTheBundleLast() {
    let paths = Uninstall.removalPaths(home: home, bundle: bundle)

    #expect(paths.last == bundle)
    #expect(paths.dropLast().allSatisfy { $0 != bundle })
}

@Test func coversEverythingLeapLeavesBehind() {
    let paths = Uninstall.removalPaths(home: home, bundle: bundle)
        .map { $0.path(percentEncoded: false) }

    #expect(paths == [
        "/Users/tester/Library/Preferences/com.antavik.leap.plist",
        "/Users/tester/Library/Containers/com.antavik.leap",
        "/Users/tester/Library/Containers/com.antavik.leap.widget",
        "/Users/tester/Library/Application Scripts/com.antavik.leap",
        "/Users/tester/Library/Application Scripts/com.antavik.leap.widget",
        "/Users/tester/Library/Saved Application State/com.antavik.leap.savedState",
        "/Users/tester/Library/Caches/com.antavik.leap",
        "/Applications/Leap.app"
    ])
}

@Test func keepsTheLegacySandboxContainers() {
    let paths = Uninstall.removalPaths(home: home, bundle: bundle)
        .map { $0.path(percentEncoded: false) }

    #expect(paths.contains("/Users/tester/Library/Containers/com.antavik.leap"))
    #expect(paths.contains("/Users/tester/Library/Preferences/com.antavik.leap.plist"))
}

@Test func staysInsideTheGivenHomeAndBundle() {
    let paths = Uninstall.removalPaths(home: home, bundle: bundle)

    #expect(paths.dropLast().allSatisfy { $0.path().hasPrefix(home.path() + "/Library/") })
}
