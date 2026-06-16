import Foundation

/// A keyboard shortcut used to drive Claude's UI (for example, the new-chat
/// shortcut). Stored in settings and rendered into AppleScript key codes.
public struct KeyboardShortcut: Codable, Sendable, Equatable {
    /// A single character key, lowercased (for example `"n"`).
    public var key: String
    public var command: Bool
    public var shift: Bool
    public var option: Bool
    public var control: Bool

    public init(
        key: String,
        command: Bool = true,
        shift: Bool = false,
        option: Bool = false,
        control: Bool = false
    ) {
        self.key = key
        self.command = command
        self.shift = shift
        self.option = option
        self.control = control
    }

    /// The default Claude new-chat shortcut: Command+N.
    public static let newChat = KeyboardShortcut(key: "n", command: true)

    /// A human-readable representation such as `⌘N`.
    public var displayString: String {
        var parts = ""
        if control { parts += "⌃" }
        if option { parts += "⌥" }
        if shift { parts += "⇧" }
        if command { parts += "⌘" }
        parts += key.uppercased()
        return parts
    }

    /// AppleScript `System Events` modifier list, for example `command down`.
    public var appleScriptModifiers: [String] {
        var mods: [String] = []
        if command { mods.append("command down") }
        if shift { mods.append("shift down") }
        if option { mods.append("option down") }
        if control { mods.append("control down") }
        return mods
    }
}
