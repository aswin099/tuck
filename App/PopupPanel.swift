import AppKit

/// Floating, non-activating panel so the previously focused app keeps focus
/// until the user picks an item.
final class PopupPanel: NSPanel {
    static let height: CGFloat = 460

    /// Called for ⌘⌫. The search field's editor would otherwise take it as
    /// "delete to the start of the line", so it's caught here first.
    var onCommandDelete: (() -> Void)?

    init(contentView: NSView) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: AppModel.listWidth, height: Self.height),
            styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .floating
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        hidesOnDeactivate = false
        isMovableByWindowBackground = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        standardWindowButton(.closeButton)?.isHidden = true
        standardWindowButton(.miniaturizeButton)?.isHidden = true
        standardWindowButton(.zoomButton)?.isHidden = true
        self.contentView = contentView
    }

    override var canBecomeKey: Bool { true }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let backspace: UInt16 = 51
        let forwardDelete: UInt16 = 117
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if modifiers == .command, event.keyCode == backspace || event.keyCode == forwardDelete,
           let onCommandDelete {
            onCommandDelete()
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    override func resignKey() {
        super.resignKey()
        orderOut(nil)
    }

    /// Places the panel just below `point` (or centered on that screen), clamped to the screen.
    func show(width: CGFloat, atCenter: Bool, near point: NSPoint) {
        let screen = NSScreen.screens.first { $0.frame.contains(point) } ?? NSScreen.main
        let bounds = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let size = NSSize(width: width, height: Self.height)
        let origin = atCenter
            ? NSPoint(x: bounds.midX - size.width / 2, y: bounds.midY - size.height / 2)
            : NSPoint(x: point.x - AppModel.listWidth / 2, y: point.y - size.height - 8)
        setFrame(Self.clamp(NSRect(origin: origin, size: size), to: bounds), display: true)
        makeKeyAndOrderFront(nil)
    }

    /// Grows or shrinks to the right, keeping the list where it is unless that would leave the screen.
    func setWidth(_ width: CGFloat) {
        guard frame.width != width else { return }
        let bounds = screen?.visibleFrame ?? frame
        var rect = frame
        rect.size.width = width
        setFrame(Self.clamp(rect, to: bounds), display: true, animate: false)
    }

    private static func clamp(_ rect: NSRect, to bounds: NSRect) -> NSRect {
        var rect = rect
        rect.origin.x = min(max(rect.origin.x, bounds.minX + 8), bounds.maxX - rect.width - 8)
        rect.origin.y = min(max(rect.origin.y, bounds.minY + 8), bounds.maxY - rect.height - 8)
        return rect
    }
}
