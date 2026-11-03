import OSLog

extension Logger {
    /// Under the running app's ID, so Debug and Release logs stay apart.
    public init(category: String) {
        self.init(subsystem: Constants.Bundles.current, category: category)
    }
}
