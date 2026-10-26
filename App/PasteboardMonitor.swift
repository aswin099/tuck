import AppKit
import TuckCore

/// Polls the general pasteboard's change count and turns new copies into `ClipItem`s.
@MainActor
final class PasteboardMonitor {
    var onItem: ((ClipItem) -> Void)?
    var rules: IgnoreRules
    var isPaused = false

    private let pasteboard = NSPasteboard.general
    private var lastChangeCount: Int
    private var timer: Timer?
    private(set) var interval: TimeInterval = 0.5

    init(rules: IgnoreRules) {
        self.rules = rules
        self.lastChangeCount = NSPasteboard.general.changeCount
    }

    func start(interval: TimeInterval = 0.5) {
        self.interval = interval
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.poll() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    /// Call after Tuck writes to the pasteboard itself, so the write is not recorded again.
    func syncChangeCount() {
        lastChangeCount = pasteboard.changeCount
    }

    private func poll() {
        let count = pasteboard.changeCount
        guard count != lastChangeCount else { return }
        lastChangeCount = count
        guard !isPaused else { return }

        let types = pasteboard.types?.map(\.rawValue) ?? []
        let app = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        guard !rules.shouldIgnore(pasteboardTypes: types, sourceApp: app) else { return }

        if let item = readItem(sourceApp: app), rules.shouldRecord(item.kind) {
            onItem?(item)
        }
    }

    private func readItem(sourceApp: String?) -> ClipItem? {
        let fileURLs = pasteboard.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        ) as? [URL]
        if let fileURLs, !fileURLs.isEmpty {
            let paths = fileURLs.map(\.path).joined(separator: "\n")
            return ClipItem(kind: .file, text: paths, sourceApp: sourceApp)
        }

        if let string = pasteboard.string(forType: .string), !string.isEmpty {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            let isLink = !trimmed.contains(" ") && !trimmed.contains("\n")
                && (trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://"))
            return ClipItem(kind: isLink ? .link : .text, text: string, sourceApp: sourceApp)
        }

        if let data = pasteboard.data(forType: .png) ?? pasteboard.data(forType: .tiff) {
            return ClipItem(kind: .image, data: data, sourceApp: sourceApp)
        }

        return nil
    }
}
