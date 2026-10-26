import AppKit
import TuckCore

/// Name and icon of an app, looked up by bundle identifier and cached.
@MainActor
enum AppInfo {
    struct Entry {
        let name: String
        let icon: NSImage?
    }

    private static var cache: [String: Entry] = [:]

    static func lookup(_ bundleID: String) -> Entry {
        if let cached = cache[bundleID] { return cached }
        let entry: Entry
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            let name = FileManager.default.displayName(atPath: url.path)
                .replacingOccurrences(of: ".app", with: "")
            entry = Entry(name: name, icon: NSWorkspace.shared.icon(forFile: url.path))
        } else {
            entry = Entry(name: bundleID, icon: nil)
        }
        cache[bundleID] = entry
        return entry
    }
}

/// Decoded images keyed by item id, so rows and the preview do not decode on every render.
@MainActor
enum ImageCache {
    private static let cache: NSCache<NSUUID, NSImage> = {
        let cache = NSCache<NSUUID, NSImage>()
        cache.countLimit = 60
        return cache
    }()

    static func image(for item: ClipItem) -> NSImage? {
        let key = item.id as NSUUID
        if let cached = cache.object(forKey: key) { return cached }
        guard let data = item.data, let image = NSImage(data: data) else { return nil }
        cache.setObject(image, forKey: key)
        return image
    }
}

extension ClipItem {
    /// Row text, with secrets replaced by dots and their kind.
    var displayPreview: String {
        guard let secretKind else { return preview }
        return "•••••••••••• \(secretKind.label)"
    }
}
