import Foundation
import AppKit
import OSLog

/// Locates the Claude desktop app without assuming a single hardcoded identity.
/// Discovery is layered: a user-selected path, then running applications, then
/// well-known install directories, matching by candidate bundle ids or by the
/// app's display name.
/// `NSWorkspace`, `FileManager`, and `UserDefaults` are documented as
/// thread-safe but are not `Sendable`; `@unchecked Sendable` reflects that the
/// stored references are safe to use across actors.
public final class DefaultClaudeAppLocator: ClaudeAppLocator, @unchecked Sendable {
    /// Candidate bundle identifiers. These are *candidates only*; matching also
    /// falls back to the app's display name so a renamed or updated bundle id
    /// does not break discovery. They are never assumed to be authoritative.
    private static let candidateBundleIDs: [String] = [
        "com.anthropic.claudefordesktop",
        "com.anthropic.claude"
    ]

    private let workspace: NSWorkspace
    private let fileManager: FileManager
    private let logger = Logger(subsystem: AppInfo.subsystem, category: "ClaudeLocator")

    public init(workspace: NSWorkspace = .shared, fileManager: FileManager = .default) {
        self.workspace = workspace
        self.fileManager = fileManager
    }

    public func locate(preferredPath: String?) -> URL? {
        if let preferredPath, !preferredPath.isEmpty {
            let url = URL(fileURLWithPath: preferredPath)
            if isValidAppBundle(url) {
                return url
            }
            logger.notice("Preferred Claude path is not a valid app bundle: \(preferredPath, privacy: .public)")
        }

        if let running = runningClaudeURL() {
            return running
        }

        return searchInstallLocations()
    }

    public func isRunning(at url: URL) -> Bool {
        let standardized = url.standardizedFileURL
        return workspace.runningApplications.contains { app in
            app.bundleURL?.standardizedFileURL == standardized
        }
    }

    // MARK: - Discovery steps

    private func runningClaudeURL() -> URL? {
        for app in workspace.runningApplications {
            if let id = app.bundleIdentifier, Self.candidateBundleIDs.contains(id),
               let url = app.bundleURL {
                return url
            }
            if let name = app.localizedName, looksLikeClaude(name),
               let url = app.bundleURL {
                return url
            }
        }
        return nil
    }

    private func searchInstallLocations() -> URL? {
        // Match by candidate bundle id first (most reliable when present).
        for id in Self.candidateBundleIDs {
            if let url = workspace.urlForApplication(withBundleIdentifier: id),
               isValidAppBundle(url) {
                return url
            }
        }

        // Then scan common directories by app name.
        var directories: [URL] = []
        directories.append(URL(fileURLWithPath: "/Applications", isDirectory: true))
        directories.append(
            fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Applications", isDirectory: true)
        )

        for directory in directories {
            guard let contents = try? fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ) else { continue }
            for candidate in contents where candidate.pathExtension == "app" {
                let base = candidate.deletingPathExtension().lastPathComponent
                if looksLikeClaude(base), isValidAppBundle(candidate) {
                    return candidate
                }
            }
        }
        return nil
    }

    // MARK: - Helpers

    private func looksLikeClaude(_ name: String) -> Bool {
        let lower = name.lowercased()
        // Match "Claude" / "Claude" desktop variants while excluding obvious
        // unrelated apps that merely contain the substring elsewhere.
        return lower == "claude" || lower.hasPrefix("claude")
    }

    private func isValidAppBundle(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        let exists = fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory)
        return exists && isDirectory.boolValue && url.pathExtension == "app"
    }
}
