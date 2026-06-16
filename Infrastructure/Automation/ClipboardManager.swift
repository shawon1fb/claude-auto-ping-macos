import Foundation
import AppKit

/// `ClipboardManager` over `NSPasteboard.general`. Snapshots capture every type
/// on the first pasteboard item so the user's clipboard can be restored after a
/// paste, including rich data.
public struct DefaultClipboardManager: ClipboardManager {
    public init() {}

    public func snapshot() -> ClipboardSnapshot {
        let pasteboard = NSPasteboard.general
        var items: [String: Data] = [:]
        // Capture the first item's representations. This preserves the common
        // case; multi-item drags are uncommon for a text clipboard and are not
        // restored to keep behavior predictable (documented as a limitation).
        if let types = pasteboard.types {
            for type in types {
                if let data = pasteboard.data(forType: type) {
                    items[type.rawValue] = data
                }
            }
        }
        return ClipboardSnapshot(items: items)
    }

    public func setString(_ string: String) throws {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        let didSet = pasteboard.setString(string, forType: .string)
        guard didSet else {
            throw AutomationError.clipboardWriteFailed
        }
    }

    public func restore(_ snapshot: ClipboardSnapshot) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        guard !snapshot.items.isEmpty else { return }
        for (type, data) in snapshot.items {
            pasteboard.setData(data, forType: NSPasteboard.PasteboardType(type))
        }
    }
}
