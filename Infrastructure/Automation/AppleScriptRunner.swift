import Foundation
import Carbon.OpenScripting

/// `AppleScriptRunner` over `NSAppleScript`. Each call compiles and executes a
/// fresh script; errors surface as `AutomationError.scriptFailed` with the OSA
/// error message preserved for diagnostics.
///
/// Importantly, this runner only ever executes scripts that the app builds
/// itself with no string-interpolated user input — the configured message is
/// delivered via the clipboard, never embedded in script source.
public struct NSAppleScriptRunner: AppleScriptRunner {
    public init() {}

    @discardableResult
    public func run(_ source: String) throws -> String? {
        guard let script = NSAppleScript(source: source) else {
            throw AutomationError.scriptFailed("Could not compile AppleScript.")
        }
        var errorInfo: NSDictionary?
        let descriptor = script.executeAndReturnError(&errorInfo)
        if let errorInfo {
            let message = (errorInfo[NSAppleScript.errorMessage] as? String) ?? "Unknown AppleScript error"
            let number = (errorInfo[NSAppleScript.errorNumber] as? Int) ?? 0
            // -1743 / -1719 indicate the user has not granted Automation access.
            if number == -1743 || number == -1719 {
                throw AutomationError.automationPermissionDenied
            }
            throw AutomationError.scriptFailed("\(message) (\(number))")
        }
        return descriptor.stringValue
    }
}
