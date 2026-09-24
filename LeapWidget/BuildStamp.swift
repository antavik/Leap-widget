import Foundation

#if DEBUG
enum BuildStamp {
    static let current: String = {
        let info = Bundle.main.infoDictionary
        let marketing = info?["CFBundleShortVersionString"] as? String ?? "?"

        guard let commit = info?["LeapBuildCommit"] as? String, !commit.isEmpty else {
            return "Version: \(marketing)."
        }

        return "Version: \(marketing) (\(commit))."
    }()
}
#endif
