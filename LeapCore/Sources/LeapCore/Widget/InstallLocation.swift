import Foundation

/// Only a copy in an Applications folder may take the widget over - not an old
/// download, nor a translocated copy whose path vanishes on quit.
public enum InstallLocation {
    public static func ownsWidget(_ bundle: URL, home: URL) -> Bool {
        let path = bundle.canonicalPath

        guard !path.contains("/AppTranslocation/") else { return false }

        return applicationFolders(home: home).contains { path.hasPrefix($0 + "/") }
    }

    static func applicationFolders(home: URL) -> [String] {
        [
            URL(filePath: "/Applications", directoryHint: .isDirectory).canonicalPath,
            home.appending(component: "Applications", directoryHint: .isDirectory).canonicalPath
        ]
    }
}
