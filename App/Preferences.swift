import Foundation
import KeyboardShortcuts
import TuckCore

extension KeyboardShortcuts.Name {
    static let togglePopup = Self("togglePopup", initial: .init(.v, modifiers: [.command, .shift]))
    static let pasteNextInQueue = Self("pasteNextInQueue", initial: .init(.v, modifiers: [.command, .control]))
    static let toggleCollecting = Self("toggleCollecting")
}

/// UserDefaults keys and their defaults. Views read them with `@AppStorage`,
/// `AppModel` applies them whenever they change.
enum Pref {
    static let historyLimit = "historyLimit"
    static let retentionDays = "retentionDays"
    static let recordText = "recordText"
    static let recordLinks = "recordLinks"
    static let recordImages = "recordImages"
    static let recordFiles = "recordFiles"
    static let pollInterval = "pollInterval"
    static let ignoredApps = "ignoredApps"
    static let skipConcealed = "skipConcealed"

    static let autoPaste = "autoPaste"
    static let popupPosition = "popupPosition"
    static let showPreview = "showPreview"
    static let showMetadata = "showMetadata"
    static let rowLines = "rowLines"
    static let showKeyHints = "showKeyHints"

    static let secretHandling = "secretHandling"
    static let secretLifetimeMinutes = "secretLifetimeMinutes"
    static let detectRandomTokens = "detectRandomTokens"
    static let clearAfterSecretPaste = "clearAfterSecretPaste"

    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            historyLimit: 200,
            retentionDays: 0,
            recordText: true,
            recordLinks: true,
            recordImages: true,
            recordFiles: true,
            pollInterval: 0.5,
            ignoredApps: "",
            skipConcealed: true,
            autoPaste: true,
            popupPosition: PopupPosition.cursor.rawValue,
            showPreview: false,
            showMetadata: true,
            rowLines: 2,
            showKeyHints: true,
            secretHandling: SecretHandling.hide.rawValue,
            secretLifetimeMinutes: 5,
            detectRandomTokens: true,
            clearAfterSecretPaste: true,
        ])
    }

    /// Bundle identifiers, stored one per line.
    static func ignoredAppIDs(from raw: String) -> [String] {
        raw.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
}

enum PopupPosition: String, CaseIterable, Identifiable {
    case cursor
    case center

    var id: Self { self }

    var label: String {
        switch self {
        case .cursor: return "At the mouse pointer"
        case .center: return "In the center of the screen"
        }
    }
}

enum SecretHandling: String, CaseIterable, Identifiable {
    case keep
    case hide
    case skip

    var id: Self { self }

    var label: String {
        switch self {
        case .keep: return "Save normally"
        case .hide: return "Save hidden"
        case .skip: return "Don't save"
        }
    }
}

extension UserDefaults {
    /// Rules for what the pasteboard monitor records, built from the current preferences.
    var ignoreRules: IgnoreRules {
        var kinds = Set<ClipKind>()
        if bool(forKey: Pref.recordText) { kinds.insert(.text) }
        if bool(forKey: Pref.recordLinks) { kinds.insert(.link) }
        if bool(forKey: Pref.recordImages) { kinds.insert(.image) }
        if bool(forKey: Pref.recordFiles) { kinds.insert(.file) }
        return IgnoreRules(
            ignoredPasteboardTypes: bool(forKey: Pref.skipConcealed) ? IgnoreRules.defaultPasteboardTypes : [],
            ignoredApps: Set(Pref.ignoredAppIDs(from: string(forKey: Pref.ignoredApps) ?? "")),
            recordedKinds: kinds
        )
    }
}
