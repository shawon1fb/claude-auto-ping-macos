import Foundation
import CoreGraphics

/// `SystemStateProvider` that reports whether the screen is locked using the
/// current Core Graphics session dictionary. When locked, the scheduler skips
/// automation instead of retrying, per the locked-Mac requirement.
public struct DefaultSystemStateProvider: SystemStateProvider {
    public init() {}

    public func isScreenLocked() -> Bool {
        guard let info = CGSessionCopyCurrentDictionary() as? [String: Any] else {
            return false
        }
        if let locked = info["CGSSessionScreenIsLocked"] as? Int {
            return locked == 1
        }
        return false
    }
}
