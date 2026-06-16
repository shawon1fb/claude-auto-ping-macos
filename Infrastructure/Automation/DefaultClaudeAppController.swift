import Foundation
import AppKit
import OSLog

/// Production `ClaudeAppController` built on `NSWorkspace`. It locates Claude,
/// launches it if needed, activates it, and polls until it is frontmost.
public final class DefaultClaudeAppController: ClaudeAppController, @unchecked Sendable {
    private let locator: ClaudeAppLocator
    private let logger = Logger(subsystem: AppInfo.subsystem, category: "AppController")
    private let readinessTimeout: TimeInterval

    public init(locator: ClaudeAppLocator, readinessTimeout: TimeInterval = 10) {
        self.locator = locator
        self.readinessTimeout = readinessTimeout
    }

    public func prepare(preferredPath: String?, launchDelay: TimeInterval) async throws -> Bool {
        guard let appURL = locator.locate(preferredPath: preferredPath) else {
            throw AutomationError.claudeNotInstalled
        }

        var didLaunch = false
        if !locator.isRunning(at: appURL) {
            try await launch(appURL)
            didLaunch = true
            try await sleep(launchDelay)
        }
        try await activate(appURL)
        try await waitUntilFrontmost(appURL)
        return didLaunch
    }

    private func launch(_ url: URL) async throws {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        do {
            _ = try await NSWorkspace.shared.openApplication(at: url, configuration: configuration)
        } catch {
            logger.error("Failed to launch Claude: \(error.localizedDescription, privacy: .public)")
            throw AutomationError.claudeLaunchFailed
        }
    }

    private func activate(_ url: URL) async throws {
        let standardized = url.standardizedFileURL
        let running = NSWorkspace.shared.runningApplications.first {
            $0.bundleURL?.standardizedFileURL == standardized
        }
        guard let app = running else {
            throw AutomationError.claudeProcessNotFound
        }
        app.activate(options: [.activateAllWindows])
    }

    private func waitUntilFrontmost(_ url: URL) async throws {
        let standardized = url.standardizedFileURL
        let deadline = Date().addingTimeInterval(readinessTimeout)
        while Date() < deadline {
            if NSWorkspace.shared.frontmostApplication?.bundleURL?.standardizedFileURL == standardized {
                return
            }
            try await sleep(0.25)
        }
        throw AutomationError.timedOut
    }

    private func sleep(_ seconds: TimeInterval) async throws {
        guard seconds > 0 else { return }
        try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }
}
