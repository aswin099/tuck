#if DEBUG
import AppKit
import TuckCore

/// Development aid for README screenshots. Launched with `-TuckDemoSnapshots <folder>`,
/// Tuck shows sample history kept in memory only: it doesn't read or write the real
/// history, touch the Keychain, watch the clipboard or register shortcuts. It saves
/// pictures of the popup and some Settings tabs into the folder, then quits.
/// Compiled out of release builds.
///
///     Tuck.app/Contents/MacOS/Tuck -TuckDemoSnapshots /tmp/tuck-shots
enum DemoMode {
    static var folder: URL? {
        UserDefaults.standard.string(forKey: "TuckDemoSnapshots").map { URL(fileURLWithPath: $0, isDirectory: true) }
    }

    static var isOn: Bool { folder != nil }

    /// Made-up history, oldest first (the store puts the newest on top).
    static func sampleItems() -> [ClipItem] {
        let now = Date()
        return [
            ClipItem(kind: .file, text: "/Users/Shared/Q3 Report.pdf", sourceApp: "com.apple.finder",
                     createdAt: now.addingTimeInterval(-3600)),
            ClipItem(kind: .text, text: "git commit -m \"Fix the popup position on a second display\"",
                     sourceApp: "com.apple.Terminal", createdAt: now.addingTimeInterval(-2400)),
            ClipItem(kind: .text, text: "Invoice 0418 is due on Friday. Thanks for the quick turnaround!",
                     sourceApp: "com.apple.mail", createdAt: now.addingTimeInterval(-1500)),
            ClipItem(kind: .image, data: sampleImage(), sourceApp: "com.apple.Preview",
                     createdAt: now.addingTimeInterval(-900)),
            ClipItem(kind: .link, text: "https://github.com/aswin099/tuck", sourceApp: "com.apple.Safari",
                     createdAt: now.addingTimeInterval(-300)),
            ClipItem(kind: .text, text: "Launch plan review moved to Thursday at 3 pm. Bring the updated timeline.",
                     sourceApp: "com.apple.Notes", createdAt: now.addingTimeInterval(-60), isPinned: true),
        ]
    }

    /// A small, colourful stand-in for a copied image.
    private static func sampleImage() -> Data? {
        let size = NSSize(width: 480, height: 300)
        let image = NSImage(size: size, flipped: false) { rect in
            NSGradient(colors: [NSColor(srgbRed: 0.17, green: 0.18, blue: 0.43, alpha: 1),
                                NSColor(srgbRed: 0.56, green: 0.58, blue: 0.95, alpha: 1)])?.draw(in: rect, angle: 35)
            NSColor(srgbRed: 1, green: 0.71, blue: 0.28, alpha: 1).setFill()
            NSBezierPath(ovalIn: NSRect(x: 340, y: 180, width: 70, height: 70)).fill()
            NSColor.white.withAlphaComponent(0.85).setFill()
            NSBezierPath(roundedRect: NSRect(x: 60, y: 70, width: 240, height: 28), xRadius: 14, yRadius: 14).fill()
            NSBezierPath(roundedRect: NSRect(x: 60, y: 120, width: 170, height: 28), xRadius: 14, yRadius: 14).fill()
            return true
        }
        guard let tiff = image.tiffRepresentation else { return nil }
        return NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:])
    }

    /// Opens the popup (without and with the preview pane) and some Settings tabs, saves each, and quits.
    @MainActor
    static func capture(_ model: AppModel) {
        guard let folder else { return }
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let previewWasOn = model.showPreview
        if previewWasOn { model.showPreview = false }
        model.showPopup()

        after(1.2) {
            save(model.demoPanel, as: "popup", in: folder)
            model.move(2)  // select the image so the preview shows something visual
            model.showPreview = true
        }
        after(2.6) {
            save(model.demoPanel, as: "popup-preview", in: folder)
            model.showPreview = previewWasOn  // put the user's setting back
            model.hidePopup()
        }
        // General, History and Popup only: Privacy would show the user's own ignored apps.
        for (step, tab) in [(0, 0), (1, 1), (2, 2)] {
            after(3.4 + Double(step) * 1.4) {
                let window = SettingsView.demoWindow(tab: tab)
                window.orderFrontRegardless()
                after(1.0) {
                    save(window, as: "settings-\(tab)", in: folder, includeTitleBar: true)
                    window.close()
                }
            }
        }
        after(8.5) { NSApp.terminate(nil) }
    }

    @MainActor
    private static func save(_ window: NSWindow?, as name: String, in folder: URL, includeTitleBar: Bool = false) {
        guard let content = window?.contentView else { return }
        let view = includeTitleBar ? (content.superview ?? content) : content
        guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: rep)
        try? rep.representation(using: .png, properties: [:])?.write(to: folder.appendingPathComponent(name + ".png"))
    }

    @MainActor
    private static func after(_ seconds: Double, _ work: @escaping @MainActor () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { MainActor.assumeIsolated { work() } }
    }
}
#endif
