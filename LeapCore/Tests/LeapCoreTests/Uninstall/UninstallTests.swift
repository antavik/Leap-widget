import Testing
import Foundation
@testable import LeapCore

@Suite("Uninstall")
struct UninstallTests {
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
        let paths = Uninstall.removalPaths(home: home, bundle: bundle,
                                           bundleIdentifier: "com.antavik.leap")

        #expect(paths.last == bundle)
        #expect(paths.dropLast().allSatisfy { $0 != bundle })
    }

    /// The exact array, in order.
    @Test func coversEverythingLeapLeavesBehind() {
        let paths = Uninstall.removalPaths(home: home, bundle: bundle,
                                           bundleIdentifier: "com.antavik.leap")
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

    /// A Debug build uninstalling itself must leave the installed app's data alone.
    @Test func aDebugBuildRemovesOnlyItsOwnData() {
        let debug = URL(filePath: "/Users/tester/Repos/Leap/build/Debug/Leap.app")
        let paths = Uninstall.removalPaths(home: home, bundle: debug,
                                           bundleIdentifier: "com.antavik.leap.debug")
            .dropLast()
            .map { $0.lastPathComponent }

        #expect(paths.allSatisfy { $0.hasPrefix("com.antavik.leap.debug") })
    }

    // MARK: - Shell and regex escaping

    /// Hostile-but-ordinary: an apostrophe, a space, a dollar, a backtick.
    private static let hostilePaths = [
        "/Users/tester/Downloads/Leap (1).app",
        "/Users/tester/Ann's Apps/Leap.app",
        "/Users/tester/$HOME/Leap.app",
        "/Users/tester/`whoami`/Leap.app",
        "/Users/tester/a b c/Leap.app",
    ]

    @Test(arguments: hostilePaths)
    func shellEscapingSurvivesASingleQuotedLiteral(path: String) throws {
        let escaped = Uninstall.shellEscaped(path)

        // Inside single quotes only the apostrophe can break out, and it is
        // the only thing the escaper may change.
        #expect(escaped.replacingOccurrences(of: "'\\''", with: "'") == path)
        #expect(try Self.echoed(singleQuoted: escaped) == path)
    }

    @Test(arguments: hostilePaths)
    func theTrampolineIsAValidShellScript(path: String) throws {
        let script = Uninstall.trampoline(
            brew: URL(filePath: "/opt/homebrew/bin/brew"),
            script: URL(filePath: path),
            log: URL(filePath: "/tmp/leap-uninstall.log"),
            processIdentifier: 4242)

        #expect(script.hasPrefix("#!/bin/sh"))
        #expect(script.contains("uninstall --cask --zap leap"))
        #expect(script.contains("pid=4242"))
        #expect(try Self.passesShellSyntaxCheck(script))
    }

    @Test(arguments: hostilePaths)
    func regexEscapingMatchesThePathAndNothingElse(path: String) throws {
        let pattern = Uninstall.regexEscaped(path)

        #expect(try Self.grepMatches(pattern: pattern, line: path))
        // A path the unescaped pattern would have matched no longer does.
        let decoy = path
            .replacingOccurrences(of: "(1)", with: "1")
            .replacingOccurrences(of: "$HOME", with: "XHOME")
            .replacingOccurrences(of: ".app", with: "Xapp")
        if decoy != path {
            #expect(try !Self.grepMatches(pattern: pattern, line: decoy))
        }
    }

    // MARK: - Shell helpers

    /// `sh -n` parses without running anything.
    private static func passesShellSyntaxCheck(_ script: String) throws -> Bool {
        try run("/bin/sh", ["-n"], stdin: script).status == 0
    }

    private static func echoed(singleQuoted escaped: String) throws -> String {
        let result = try run("/bin/sh", ["-c", "printf %s '\(escaped)'"], stdin: nil)
        return result.output
    }

    private static func grepMatches(pattern: String, line: String) throws -> Bool {
        try run("/usr/bin/grep", ["-E", pattern], stdin: line + "\n").status == 0
    }

    private static func run(_ tool: String,
                            _ arguments: [String],
                            stdin: String?) throws -> (status: Int32, output: String) {
        let process = Process()
        process.executableURL = URL(filePath: tool)
        process.arguments = arguments

        let input = Pipe()
        let output = Pipe()
        process.standardInput = input
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice

        try process.run()
        if let stdin { input.fileHandleForWriting.write(Data(stdin.utf8)) }
        input.fileHandleForWriting.closeFile()

        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        return (process.terminationStatus, String(decoding: data, as: UTF8.self))
    }
}
