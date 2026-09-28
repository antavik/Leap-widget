import Foundation

enum SystemTool {
    static let lsregister =
        "/System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister"

    /// Exit status, or `launchFailed`. Never throws.
    @discardableResult
    static func run(_ tool: String, _ arguments: [String]) async -> Int32 {
        let process = Process()
        process.executableURL = URL(filePath: tool)
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        return await withCheckedContinuation { (continuation: CheckedContinuation<Int32, Never>) in
            process.terminationHandler = { continuation.resume(returning: $0.terminationStatus) }
            do {
                try process.run()
            } catch {
                continuation.resume(returning: launchFailed)
            }
        }
    }

    static let launchFailed: Int32 = -1
}
