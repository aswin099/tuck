import AppKit
import ApplicationServices
import TuckCore

/// Puts an item back on the pasteboard and simulates ⌘V in the frontmost app.
enum Paster {
    static func write(_ item: ClipItem) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        switch item.kind {
        case .image:
            if let data = item.data, let image = NSImage(data: data) {
                pasteboard.writeObjects([image])
            }
        case .file:
            let urls = (item.text ?? "")
                .split(separator: "\n")
                .map { URL(fileURLWithPath: String($0)) as NSURL }
            pasteboard.writeObjects(urls)
        case .text, .link:
            pasteboard.setString(item.text ?? "", forType: .string)
        }
    }

    /// Returns `false` when the Accessibility permission is missing.
    @discardableResult
    static func sendPaste() -> Bool {
        guard AXIsProcessTrusted() else { return false }
        let source = CGEventSource(stateID: .combinedSessionState)
        let vKey: CGKeyCode = 0x09
        let down = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: true)
        let up = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: false)
        down?.flags = .maskCommand
        up?.flags = .maskCommand
        down?.post(tap: .cgAnnotatedSessionEventTap)
        up?.post(tap: .cgAnnotatedSessionEventTap)
        return true
    }

    static func requestAccessibility() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }
}
