import Foundation

extension URL {
    /// Symlinks resolved, no trailing slash.
    var canonicalPath: String {
        let path = standardizedFileURL
            .resolvingSymlinksInPath()
            .path(percentEncoded: false)

        return path.count > 1 && path.hasSuffix("/") ? String(path.dropLast()) : path
    }
}
