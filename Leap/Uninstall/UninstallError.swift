import Foundation

enum UninstallError: LocalizedError {
    case handoffFailed(underlying: any Error)

    var errorDescription: String? {
        switch self {
        case .handoffFailed(let underlying):
            String(localized: "Leap could not hand the uninstall over to Homebrew. \(underlying.localizedDescription)",
                   comment: "Uninstall failure message")
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .handoffFailed:
            String(localized: "Run “brew uninstall --cask --zap leap” in Terminal instead.",
                   comment: "Uninstall failure recovery suggestion")
        }
    }
}
