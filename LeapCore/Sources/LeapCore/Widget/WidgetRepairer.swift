import Foundation
import OSLog

/// Fixes what an update leaves behind: stray copies' LaunchServices records
/// make the host reject renders, and cached renders miss appearances until
/// the host restarts. The steps and their order live here; every system call
/// is injected.
@MainActor
public struct WidgetRepairer {
    public enum Outcome: Equatable, Sendable {
        case repaired
        case skipped            // UI test safe mode
        case hostRestartFailed
    }

    public struct System {
        /// Every copy LaunchServices knows under the app's bundle ID.
        public var registeredCopies: @MainActor () -> [URL]
        /// Records only; files stay.
        public var unregister: @MainActor (URL) async -> Void
        public var register: @MainActor (URL) async -> Void
        /// False when the host could not be restarted.
        public var restartHost: @MainActor () async -> Bool
        public var reloadTimelines: @MainActor () -> Void

        public init(registeredCopies: @escaping @MainActor () -> [URL],
                    unregister: @escaping @MainActor (URL) async -> Void,
                    register: @escaping @MainActor (URL) async -> Void,
                    restartHost: @escaping @MainActor () async -> Bool,
                    reloadTimelines: @escaping @MainActor () -> Void) {
            self.registeredCopies = registeredCopies
            self.unregister = unregister
            self.register = register
            self.restartHost = restartHost
            self.reloadTimelines = reloadTimelines
        }
    }

    private static let log = Logger(category: "WidgetRepair")

    private let app: URL
    private let ownsWidget: Bool
    private let isSafeMode: Bool
    private let system: System

    /// `ownsWidget` false: a copy that must not take the gallery over only
    /// restarts the host.
    public init(app: URL, ownsWidget: Bool, isSafeMode: Bool, system: System) {
        self.app = app
        self.ownsWidget = ownsWidget
        self.isSafeMode = isSafeMode
        self.system = system
    }

    /// Marks the build repaired only on success, so a failed repair retries.
    public func repairIfUpdated(build: String, marker: BuildMarker) async {
        guard !isSafeMode, ownsWidget, marker.isBehind(build),
              await repair() == .repaired
        else { return }

        _ = marker.advance(to: build)
    }

    @discardableResult
    public func repair() async -> Outcome {
        // The restart would redraw the real user's Desktop.
        guard !isSafeMode else {
            Self.log.info("LEAP_UI_TEST_SAFE_MODE: skipped widget repair")
            return .skipped
        }

        Self.log.info("Repairing widgets for \(BuildMarker.build(of: .main), privacy: .public)")

        if ownsWidget {
            for copy in StrayCopies.among(system.registeredCopies(), running: app) {
                Self.log.info("Unregistering stray copy \(copy.path(percentEncoded: false), privacy: .public)")
                await system.unregister(copy)
            }

            await system.register(app)
        } else {
            Self.log.info("Not registering \(app.path(percentEncoded: false), privacy: .public): only an installed copy owns the widget")
        }

        guard await system.restartHost() else {
            Self.log.error("Could not restart the widget host")
            return .hostRestartFailed
        }

        system.reloadTimelines()

        return .repaired
    }
}
