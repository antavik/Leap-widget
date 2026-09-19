import Testing
import Foundation
import CoreGraphics

/// Where golden images live, and what toolchain rasterised them.
///
/// Read and written through `#filePath`, never `Bundle.module`: a bundle copy
/// is a build product, so recording would write the source tree while
/// verification read a stale copy, and a golden that should fail would pass.
enum GoldenStore {
    static let recordEnvironmentKey = "LEAP_RECORD_SNAPSHOTS"
    static let skipEnvironmentKey = "LEAP_SKIP_SNAPSHOTS"
    /// Set by the report harness; every render is written here, not only failures.
    static let screenshotsEnvironmentKey = "LEAP_SCREENSHOTS_DIR"
    /// Points the expected/actual/diff triple at the current report's folder.
    static let diffEnvironmentKey = "LEAP_DIFF_DIR"

    static var isRecording: Bool {
        ProcessInfo.processInfo.environment[recordEnvironmentKey] != nil
    }

    static var isSkipped: Bool {
        ProcessInfo.processInfo.environment[skipEnvironmentKey] != nil
    }

    static var screenshotsDirectory: URL? {
        ProcessInfo.processInfo.environment[screenshotsEnvironmentKey]
            .map { URL(filePath: $0) }
    }

    /// `<repo>/LeapCore/Tests/LeapCoreTests`.
    static let testsDirectory = URL(filePath: #filePath)
        .deletingLastPathComponent()      // Support/
        .deletingLastPathComponent()      // LeapCoreTests/

    /// OS **and** Xcode major: the OS alone misses the rasteriser, so a
    /// toolchain bump stays an additive, reviewed change.
    static let toolchainKey =
        "\(Toolchain.osMajorVersion)-\(Toolchain.xcodeMajorVersion ?? 0)"

    static let directory = testsDirectory
        .appending(component: "__Goldens__")
        .appending(component: toolchainKey)

    static var isAvailable: Bool {
        FileManager.default.fileExists(atPath: directory.path(percentEncoded: false))
    }

    /// On a pinned runner a skip means the key is wrong, not that the layer is
    /// unavailable — CI fails when this suite skips.
    static var unavailableReason: Comment {
        """
        no goldens recorded for toolchain \(toolchainKey) \
        (\(Toolchain.description)) — record them with `make snapshots-record`
        """
    }

    static func url(for id: String) -> URL {
        directory.appending(component: "\(id).png")
    }

    static func write(_ image: CGImage, id: String) throws {
        try FileManager.default.createDirectory(at: directory,
                                                withIntermediateDirectories: true)
        guard let data = ImageComparator.pngData(of: image) else {
            throw GoldenError.encodingFailed(id)
        }
        try data.write(to: url(for: id), options: .atomic)
        try writeToolchainStamp()
    }

    static func read(id: String) throws -> CGImage {
        let data = try Data(contentsOf: url(for: id))
        guard let image = ImageComparator.image(fromPNG: data) else {
            throw GoldenError.decodingFailed(id)
        }
        return image
    }

    static func exists(id: String) -> Bool {
        FileManager.default.fileExists(atPath: url(for: id).path(percentEncoded: false))
    }

    /// The toolchain that recorded the images, beside the images.
    static func writeToolchainStamp() throws {
        let stamp = directory.appending(component: "toolchain.txt")
        try Toolchain.description.appending("\n")
            .write(to: stamp, atomically: true, encoding: .utf8)
    }

    static let repositoryDirectory = testsDirectory
        .deletingLastPathComponent()      // Tests/
        .deletingLastPathComponent()      // LeapCore/
        .deletingLastPathComponent()      // <repo>/

    /// Diff output for the inner loop; nobody opens an xUnit attachment
    /// mid-edit. Outside a report run these go to a plain `reports/diff/` —
    /// never `reports/latest`, which is a symlink the harness maintains, and
    /// which creating as a real directory here silently broke.
    static var diffDirectory: URL {
        if let named = ProcessInfo.processInfo.environment[diffEnvironmentKey] {
            return URL(filePath: named)
        }

        return repositoryDirectory.appending(components: "reports", "diff")
    }

    static func writeDiff(_ image: CGImage, named name: String) {
        guard let data = ImageComparator.pngData(of: image) else { return }

        try? FileManager.default.createDirectory(at: diffDirectory,
                                                 withIntermediateDirectories: true)
        try? data.write(to: diffDirectory.appending(component: name), options: .atomic)
    }

    static func writeScreenshot(_ image: CGImage, id: String) {
        guard let directory = screenshotsDirectory,
              let data = ImageComparator.pngData(of: image)
        else { return }

        try? FileManager.default.createDirectory(at: directory,
                                                 withIntermediateDirectories: true)
        try? data.write(to: directory.appending(component: "\(id).png"), options: .atomic)
    }
}

enum GoldenError: Error, CustomStringConvertible {
    case encodingFailed(String)
    case decodingFailed(String)

    var description: String {
        switch self {
        case .encodingFailed(let id): "could not encode golden \(id) as PNG"
        case .decodingFailed(let id): "could not decode golden \(id)"
        }
    }
}

/// Resolved without spawning a process where possible.
enum Toolchain {
    static var osMajorVersion: Int {
        ProcessInfo.processInfo.operatingSystemVersion.majorVersion
    }

    static let osVersion = ProcessInfo.processInfo.operatingSystemVersionString

    /// `CFBundleShortVersionString` from the selected Xcode's `version.plist`.
    static let xcodeVersion: String? = {
        guard let developerDirectory else { return nil }

        let plist = URL(filePath: developerDirectory)
            .deletingLastPathComponent()          // …/Xcode.app/Contents
            .appending(component: "version.plist")

        guard let data = try? Data(contentsOf: plist),
              let root = try? PropertyListSerialization.propertyList(
                from: data, format: nil) as? [String: Any]
        else { return nil }

        return root["CFBundleShortVersionString"] as? String
    }()

    static var xcodeMajorVersion: Int? {
        xcodeVersion?.split(separator: ".").first.flatMap { Int($0) }
    }

    static let description = "macOS \(osVersion), Xcode \(xcodeVersion ?? "unknown")"

    private static let developerDirectory: String? = {
        if let fromEnvironment = ProcessInfo.processInfo.environment["DEVELOPER_DIR"] {
            return fromEnvironment
        }

        let process = Process()
        process.executableURL = URL(filePath: "/usr/bin/xcode-select")
        process.arguments = ["-p"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        guard (try? process.run()) != nil else { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        let path = String(decoding: data, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return path.isEmpty ? nil : path
    }()
}
