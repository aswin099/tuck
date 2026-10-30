import AppKit
import SwiftUI
import TuckCore
import KeyboardShortcuts

@MainActor
final class AppModel: ObservableObject {
    static let shared = AppModel()

    @Published var query = "" {
        didSet { refresh() }
    }
    @Published private(set) var visibleItems: [ClipItem] = []
    @Published var selection: UUID?
    @Published var focusToken = 0
    @Published var isPaused = false {
        didSet { monitor.isPaused = isPaused }
    }
    @Published private(set) var queue = PasteQueue()
    /// When on, every new copy is also added to the paste queue.
    @Published var isCollecting = false
    @Published var showPreview = UserDefaults.standard.bool(forKey: Pref.showPreview) {
        didSet {
            UserDefaults.standard.set(showPreview, forKey: Pref.showPreview)
            panel?.setWidth(popupWidth)
        }
    }

    enum StorageStatus: Equatable {
        case encrypted
        /// The previous file could not be decrypted and was set aside.
        case recovered(movedTo: URL)
        /// The Keychain was unavailable, so history is not saved to disk.
        case memoryOnly(reason: String)
    }

    let historyFileURL: URL
    let storageStatus: StorageStatus
    private let store: HistoryStore
    private let monitor: PasteboardMonitor
    private var panel: PopupPanel?
    private var previousApp: NSRunningApplication?
    private var pruneTimer: Timer?
    private var defaultsObserver: NSObjectProtocol?

    static let listWidth: CGFloat = 380
    static let previewWidth: CGFloat = 320
    var popupWidth: CGFloat { showPreview ? Self.listWidth + Self.previewWidth : Self.listWidth }

    private var defaults: UserDefaults { .standard }

    private init() {
        Pref.registerDefaults()
        #if DEBUG
        // Demo mode (README screenshots): sample history in memory only. No history file,
        // no Keychain, no clipboard monitoring.
        if DemoMode.isOn {
            historyFileURL = FileManager.default.temporaryDirectory.appendingPathComponent("tuck-demo.tuck")
            storageStatus = .encrypted
            store = HistoryStore(maxItems: 200)
            monitor = PasteboardMonitor(rules: UserDefaults.standard.ignoreRules)
            return
        }
        #endif
        let support = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Tuck", isDirectory: true)
        try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)

        historyFileURL = support.appendingPathComponent("history.tuck")
        // Versions before encryption saved plain JSON here. The store reads it once
        // and rewrites it encrypted.
        let legacyURL = support.appendingPathComponent("history.json")
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: legacyURL.path), !fileManager.fileExists(atPath: historyFileURL.path) {
            try? fileManager.moveItem(at: legacyURL, to: historyFileURL)
        }

        let limit = UserDefaults.standard.integer(forKey: Pref.historyLimit)
        do {
            let cipher = AESGCMCipher(key: try HistoryKey.loadOrCreate())
            store = HistoryStore(maxItems: limit, fileURL: historyFileURL, cipher: cipher)
            switch store.loadResult {
            case .empty, .loaded, .migrated:
                storageStatus = .encrypted
            case .unreadable(let movedTo):
                storageStatus = .recovered(movedTo: movedTo)
            }
        } catch {
            // Without a key, never fall back to writing plain text.
            store = HistoryStore(maxItems: limit)
            storageStatus = .memoryOnly(reason: String(describing: error))
        }
        monitor = PasteboardMonitor(rules: UserDefaults.standard.ignoreRules)
    }

    func start() {
        #if DEBUG
        if DemoMode.isOn {
            DemoMode.sampleItems().forEach { _ = store.add($0) }
            refresh()
            DemoMode.capture(self)
            return
        }
        #endif
        monitor.onItem = { [weak self] item in
            self?.ingest(item)
        }
        monitor.start(interval: defaults.double(forKey: Pref.pollInterval))
        KeyboardShortcuts.onKeyDown(for: .togglePopup) { [weak self] in
            Task { @MainActor in self?.togglePopup() }
        }
        KeyboardShortcuts.onKeyDown(for: .pasteNextInQueue) { [weak self] in
            Task { @MainActor in self?.pasteNextInQueue() }
        }
        KeyboardShortcuts.onKeyDown(for: .toggleCollecting) { [weak self] in
            Task { @MainActor in self?.isCollecting.toggle() }
        }
        defaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            // Delivered on the main queue, so no hop is needed.
            MainActor.assumeIsolated { self?.applySettings() }
        }
        pruneTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            // Scheduled on the main run loop, so this already runs on the main thread.
            MainActor.assumeIsolated { self?.prune() }
        }
        prune()
        refresh()
    }

    // MARK: - Recording

    private func ingest(_ item: ClipItem) {
        var item = item
        if item.kind == .text || item.kind == .link,
           let text = item.text,
           let kind = SecretDetector.detect(text, includeRandomTokens: defaults.bool(forKey: Pref.detectRandomTokens)) {
            switch SecretHandling(rawValue: defaults.string(forKey: Pref.secretHandling) ?? "") ?? .hide {
            case .skip:
                return
            case .hide:
                item.secretKind = kind
                let minutes = defaults.integer(forKey: Pref.secretLifetimeMinutes)
                if minutes > 0 { item.expiresAt = Date().addingTimeInterval(TimeInterval(minutes * 60)) }
            case .keep:
                break
            }
        }
        let stored = store.add(item)
        if isCollecting { queue.enqueue(stored) }
        refresh()
    }

    private func prune() {
        let days = defaults.integer(forKey: Pref.retentionDays)
        let maxAge = days > 0 ? TimeInterval(days) * 86_400 : nil
        if store.prune(maxAge: maxAge) { refresh() }
    }

    // MARK: - Popup

    func togglePopup() {
        if panel?.isVisible == true { hidePopup() } else { showPopup() }
    }

    func showPopup() {
        previousApp = NSWorkspace.shared.frontmostApplication
        query = ""
        refresh()
        if panel == nil {
            let host = NSHostingView(rootView: PopupView().environmentObject(self))
            panel = PopupPanel(contentView: host)
        }
        focusToken += 1
        let position = PopupPosition(rawValue: defaults.string(forKey: Pref.popupPosition) ?? "") ?? .cursor
        panel?.show(width: popupWidth, atCenter: position == .center, near: NSEvent.mouseLocation)
    }

    func hidePopup() {
        panel?.orderOut(nil)
    }

    #if DEBUG
    /// For demo-mode screenshots.
    var demoPanel: NSWindow? { panel }
    #endif

    // MARK: - Actions

    var selectedItem: ClipItem? {
        visibleItems.first { $0.id == selection }
    }

    var pinnedCount: Int { store.items.filter(\.isPinned).count }
    var totalCount: Int { store.items.count }

    func refresh() {
        visibleItems = Search.filter(store.items, query: query)
        if selection == nil || !visibleItems.contains(where: { $0.id == selection }) {
            selection = visibleItems.first?.id
        }
        objectWillChange.send()
    }

    func move(_ delta: Int) {
        guard !visibleItems.isEmpty else { return }
        let current = visibleItems.firstIndex { $0.id == selection } ?? 0
        let next = min(max(current + delta, 0), visibleItems.count - 1)
        selection = visibleItems[next].id
    }

    func pasteSelected() {
        guard let item = selectedItem else { return }
        paste(item)
    }

    func paste(at index: Int) {
        guard visibleItems.indices.contains(index) else { return }
        paste(visibleItems[index])
    }

    func paste(_ item: ClipItem) {
        hidePopup()
        previousApp?.activate()
        deliver(item)
        store.touch(item.id)
        refresh()
    }

    /// Writes the item to the pasteboard and, if enabled, sends ⌘V to the frontmost app.
    private func deliver(_ item: ClipItem) {
        Paster.write(item)
        monitor.syncChangeCount()
        let changeCount = NSPasteboard.general.changeCount

        guard defaults.bool(forKey: Pref.autoPaste) else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            if !Paster.sendPaste() {
                Paster.requestAccessibility()
            }
        }
        if item.isSecret, defaults.bool(forKey: Pref.clearAfterSecretPaste) {
            // Give the target app time to read the pasteboard, then clear it unless
            // something else was copied in the meantime.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                guard NSPasteboard.general.changeCount == changeCount else { return }
                NSPasteboard.general.clearContents()
                self?.monitor.syncChangeCount()
            }
        }
    }

    func deleteSelected() {
        guard let id = selection else { return }
        store.delete(id)
        queue.remove(id)
        refresh()
    }

    func togglePinSelected() {
        guard let id = selection else { return }
        store.togglePin(id)
        refresh()
    }

    func clearHistory() {
        store.clearUnpinned()
        refresh()
    }

    /// Asks before clearing, as the menu bar item cannot be undone.
    func confirmClearHistory() {
        let alert = NSAlert()
        alert.messageText = "Clear clipboard history?"
        alert.informativeText = "All items except pinned ones will be deleted. This can't be undone."
        alert.addButton(withTitle: "Clear History")
        alert.addButton(withTitle: "Cancel")
        alert.buttons.first?.hasDestructiveAction = true
        NSApp.activate()
        if alert.runModal() == .alertFirstButtonReturn { clearHistory() }
    }

    // MARK: - Paste queue

    func toggleQueuedSelected() {
        guard let item = selectedItem else { return }
        if queue.position(of: item) != nil {
            queue.remove(item.id)
        } else {
            queue.enqueue(item)
        }
    }

    /// Pastes the front of the queue into the frontmost app and removes it.
    func pasteNextInQueue() {
        guard let item = queue.next() else {
            NSSound.beep()
            return
        }
        deliver(item)
        store.touch(item.id)
        refresh()
    }

    func clearQueue() {
        queue.clear()
        isCollecting = false
    }

    // MARK: - Settings

    private func applySettings() {
        let limit = defaults.integer(forKey: Pref.historyLimit)
        if limit != store.maxItems { store.setMaxItems(limit) }

        let rules = defaults.ignoreRules
        if rules != monitor.rules { monitor.rules = rules }

        let interval = defaults.double(forKey: Pref.pollInterval)
        if interval > 0, interval != monitor.interval { monitor.start(interval: interval) }

        let preview = defaults.bool(forKey: Pref.showPreview)
        if preview != showPreview { showPreview = preview }

        prune()
        refresh()
    }
}
