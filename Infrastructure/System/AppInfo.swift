import Foundation

/// Static identifiers shared across the app (logging subsystem, bundle id,
/// support directory). Keeping these in one place avoids stringly-typed drift.
public enum AppInfo {
    public static let subsystem = "com.opensource.claudeautopingmacos"
    public static let displayName = "Claude Auto Ping macOS"

    /// `~/Library/Application Support/ClaudeAutoPingMacos`, created on demand.
    public static var supportDirectoryURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
        return base.appendingPathComponent("ClaudeAutoPingMacos", isDirectory: true)
    }
}
