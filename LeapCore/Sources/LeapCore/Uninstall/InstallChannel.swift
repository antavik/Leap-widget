import Foundation

public enum InstallChannel: Equatable, Sendable {
    case homebrew(brew: URL)
    case direct
}
