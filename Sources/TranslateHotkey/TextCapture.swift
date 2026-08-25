import AppKit
import ApplicationServices
import Carbon.HIToolbox

/// Captures the contents of the focused input field (via synthesized ⌘A ⌘C)
/// and replaces it (via synthesized ⌘V), while preserving the user's clipboard.
enum TextCapture {

    typealias PasteboardSnapshot = [[NSPasteboard.PasteboardType: Data]]

    // MARK: - Accessibility permission

    /// Returns true if the app is allowed to synthesize keyboard events.
    /// When `prompt` is true, macOS shows the system dialog that sends the
    /// user to System Settings → Privacy & Security → Accessibility.
    static func ensureAccessibility(prompt: Bool) -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [key: prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    // MARK: - Clipboard preservation

    static func snapshotPasteboard() -> PasteboardSnapshot {
        (NSPasteboard.general.pasteboardItems ?? []).map { item in
            var entry: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) {
                    entry[type] = data
                }
            }
            return entry
        }
    }

    static func restorePasteboard(_ snapshot: PasteboardSnapshot) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        guard !snapshot.isEmpty else { return }
        let items: [NSPasteboardItem] = snapshot.map { entry in
            let item = NSPasteboardItem()
            for (type, data) in entry {
                item.setData(data, forType: type)
            }
            return item
        }
        pasteboard.writeObjects(items)
    }

    // MARK: - Key synthesis

    /// Waits (up to `timeout` seconds) for the user to release all modifier
    /// keys. Without this, the ⌥⌘ still held down from triggering the hotkey
    /// would combine with the synthesized ⌘A and produce the wrong shortcut.
    static func waitForModifierRelease(timeout: TimeInterval = 1.5) {
        let deadline = Date().addingTimeInterval(timeout)
        let watched: [CGKeyCode] = [
            CGKeyCode(kVK_Command), CGKeyCode(kVK_RightCommand),
            CGKeyCode(kVK_Option), CGKeyCode(kVK_RightOption),
            CGKeyCode(kVK_Control), CGKeyCode(kVK_RightControl),
            CGKeyCode(kVK_Shift), CGKeyCode(kVK_RightShift),
        ]
        while Date() < deadline {
            let anyDown = watched.contains {
                CGEventSource.keyState(.combinedSessionState, key: $0)
            }
            if !anyDown { return }
            usleep(20_000)
        }
    }

    private static func sendKey(_ keyCode: CGKeyCode, flags: CGEventFlags) {
        let source = CGEventSource(stateID: .combinedSessionState)
        guard
            let down = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
            let up = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        else { return }
        down.flags = flags
        up.flags = []
        down.post(tap: .cghidEventTap)
        usleep(15_000)
        up.post(tap: .cghidEventTap)
    }

    // MARK: - High-level operations

    /// Synthesizes ⌘A then ⌘C in the frontmost app and returns the copied
    /// plain text, or nil if nothing was copied (e.g. the field is empty or
    /// the app blocked the copy).
    static func selectAllAndCopy() -> String? {
        let pasteboard = NSPasteboard.general
        let changeCountBefore = pasteboard.changeCount

        sendKey(CGKeyCode(kVK_ANSI_A), flags: .maskCommand)
        usleep(80_000)
        sendKey(CGKeyCode(kVK_ANSI_C), flags: .maskCommand)

        // Wait up to ~1.5s for the pasteboard to actually change.
        for _ in 0..<60 {
            if pasteboard.changeCount != changeCountBefore { break }
            usleep(25_000)
        }
        guard pasteboard.changeCount != changeCountBefore else { return nil }
        return pasteboard.string(forType: .string)
    }

    /// Synthesizes ⌘A then pastes `text`, replacing the entire contents of
    /// the focused input field. Used by "Restore Original Text".
    static func replaceAll(with text: String) {
        sendKey(CGKeyCode(kVK_ANSI_A), flags: .maskCommand)
        usleep(80_000)
        paste(text)
    }

    /// Puts `text` on the pasteboard and synthesizes ⌘V in the frontmost app.
    static func paste(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        usleep(60_000)
        sendKey(CGKeyCode(kVK_ANSI_V), flags: .maskCommand)
    }
}
