import AppKit

/// Minimal app delegate. The app is a menu-bar accessory, so it keeps the
/// activation policy as `.accessory` and prevents a Dock icon or main window.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }
}
