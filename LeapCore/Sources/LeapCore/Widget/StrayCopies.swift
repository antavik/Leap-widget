import Foundation

/// Registered copies other than the running one. The host may match the
/// extension against one and reject renders ("Bundle version did not match").
public enum StrayCopies {
    /// Every registered copy but `running`, each once, in the order given.
    public static func among(_ registered: [URL], running: URL) -> [URL] {
        var seen: Set<String> = [running.canonicalPath]

        return registered.filter { seen.insert($0.canonicalPath).inserted }
    }
}
