import SwiftUI
import ServiceManagement
import KeyboardShortcuts
import UniformTypeIdentifiers
import ApplicationServices

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettings()
                .tabItem { Label("General", systemImage: "gearshape") }
            HistorySettings()
                .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }
            PopupSettings()
                .tabItem { Label("Popup", systemImage: "macwindow") }
            PrivacySettings()
                .tabItem { Label("Privacy", systemImage: "hand.raised") }
            AboutSettings()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 520)
        // Tuck has no Dock icon, so bring the window forward when it opens.
        .onAppear { NSApp.activate() }
    }
}

// MARK: - General

private struct GeneralSettings: View {
    @AppStorage(Pref.autoPaste) private var autoPaste = true
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var isTrusted = AXIsProcessTrusted()

    var body: some View {
        Form {
            Section("Keyboard shortcuts") {
                KeyboardShortcuts.Recorder("Open Tuck", name: .togglePopup)
                KeyboardShortcuts.Recorder("Paste next from queue", name: .pasteNextInQueue)
                KeyboardShortcuts.Recorder("Start or stop collecting", name: .toggleCollecting)
            }

            Section {
                Toggle("Paste into the active app", isOn: $autoPaste)
                if autoPaste {
                    LabeledContent("Accessibility") {
                        if isTrusted {
                            Label("Allowed", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        } else {
                            Button("Open System Settings…") { openAccessibilitySettings() }
                        }
                    }
                }
            } header: {
                Text("Pasting")
            } footer: {
                Text(autoPaste
                     ? "Tuck sends ⌘V for you, which needs the Accessibility permission."
                     : "Tuck copies the item and you press ⌘V yourself.")
                    .settingsFootnote()
            }

            Section("Startup") {
                Toggle("Open Tuck at login", isOn: $launchAtLogin)
            }
        }
        .formStyle(.grouped)
        .frame(height: 450)
        .onChange(of: launchAtLogin) { _, enabled in
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                launchAtLogin = SMAppService.mainApp.status == .enabled
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            isTrusted = AXIsProcessTrusted()
        }
    }

    private func openAccessibilitySettings() {
        Paster.requestAccessibility()
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - History

private struct HistorySettings: View {
    @AppStorage(Pref.historyLimit) private var historyLimit = 200
    @AppStorage(Pref.retentionDays) private var retentionDays = 0
    @AppStorage(Pref.recordText) private var recordText = true
    @AppStorage(Pref.recordLinks) private var recordLinks = true
    @AppStorage(Pref.recordImages) private var recordImages = true
    @AppStorage(Pref.recordFiles) private var recordFiles = true
    @AppStorage(Pref.pollInterval) private var pollInterval = 0.5
    @ObservedObject private var model = AppModel.shared
    @State private var confirmingClear = false

    var body: some View {
        Form {
            Section {
                Picker("Keep up to", selection: $historyLimit) {
                    ForEach([50, 100, 200, 500, 1000], id: \.self) { count in
                        Text("\(count) items").tag(count)
                    }
                }
                Picker("Delete items after", selection: $retentionDays) {
                    Text("Never").tag(0)
                    Text("1 day").tag(1)
                    Text("1 week").tag(7)
                    Text("1 month").tag(30)
                    Text("3 months").tag(90)
                }
            } header: {
                Text("Storage")
            } footer: {
                Text("Pinned items are never deleted automatically.")
                    .settingsFootnote()
            }

            Section("Save these kinds of items") {
                Toggle("Text", isOn: $recordText)
                Toggle("Links", isOn: $recordLinks)
                Toggle("Images", isOn: $recordImages)
                Toggle("Files", isOn: $recordFiles)
            }

            Section {
                Picker("Check the clipboard", selection: $pollInterval) {
                    Text("Every 0.25 seconds").tag(0.25)
                    Text("Every 0.5 seconds").tag(0.5)
                    Text("Every second").tag(1.0)
                    Text("Every 2 seconds").tag(2.0)
                }
            } footer: {
                Text("Checking more often catches quick copies but uses a little more energy.")
                    .settingsFootnote()
            }

            Section {
                LabeledContent("Saved items") {
                    Text(model.pinnedCount > 0
                         ? "\(model.totalCount) (\(model.pinnedCount) pinned)"
                         : "\(model.totalCount)")
                }
                LabeledContent("Storage") {
                    storageLabel
                }
                HStack {
                    Button("Show in Finder") {
                        NSWorkspace.shared.activateFileViewerSelecting([model.historyFileURL])
                    }
                    .disabled(!FileManager.default.fileExists(atPath: model.historyFileURL.path))
                    Spacer()
                    Button("Clear History…", role: .destructive) { confirmingClear = true }
                        .disabled(model.totalCount == model.pinnedCount)
                }
            } footer: {
                Text(storageFootnote)
                    .settingsFootnote()
            }
        }
        .formStyle(.grouped)
        .frame(height: 610)
        .confirmationDialog("Clear clipboard history?", isPresented: $confirmingClear) {
            Button("Clear History", role: .destructive) { model.clearHistory() }
        } message: {
            Text("All items except pinned ones will be deleted. This can't be undone.")
        }
    }

    @ViewBuilder
    private var storageLabel: some View {
        switch model.storageStatus {
        case .encrypted:
            Label("Encrypted", systemImage: "lock.fill")
        case .recovered:
            Label("Encrypted, started fresh", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
        case .memoryOnly:
            Label("Not saved to disk", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
        }
    }

    private var storageFootnote: String {
        switch model.storageStatus {
        case .encrypted:
            return "History is encrypted with a key kept in your Keychain. Hidden secrets are never written to disk."
        case .recovered(let movedTo):
            return "The previous history file couldn't be decrypted, so it was kept as \(movedTo.lastPathComponent) and a new one was started."
        case .memoryOnly(let reason):
            return "Tuck couldn't use the Keychain (\(reason)), so history is kept only until Tuck quits."
        }
    }
}

// MARK: - Popup

private struct PopupSettings: View {
    @AppStorage(Pref.popupPosition) private var position = PopupPosition.cursor
    @AppStorage(Pref.showPreview) private var showPreview = false
    @AppStorage(Pref.showMetadata) private var showMetadata = true
    @AppStorage(Pref.rowLines) private var rowLines = 2
    @AppStorage(Pref.showKeyHints) private var showKeyHints = true

    var body: some View {
        Form {
            Section("Window") {
                Picker("Open popup", selection: $position) {
                    ForEach(PopupPosition.allCases) { position in
                        Text(position.label).tag(position)
                    }
                }
                Toggle(isOn: $showPreview) {
                    Text("Show preview pane")
                    Text("Press ⌘Y in the popup to show or hide it.")
                }
            }

            Section("Items") {
                Picker("Lines of text", selection: $rowLines) {
                    Text("1").tag(1)
                    Text("2").tag(2)
                    Text("3").tag(3)
                }
                .pickerStyle(.segmented)
                Toggle("Show source app and time", isOn: $showMetadata)
                Toggle("Show keyboard hints", isOn: $showKeyHints)
            }
        }
        .formStyle(.grouped)
        .frame(height: 330)
    }
}

// MARK: - Privacy

private struct PrivacySettings: View {
    @AppStorage(Pref.skipConcealed) private var skipConcealed = true
    @AppStorage(Pref.secretHandling) private var secretHandling = SecretHandling.hide
    @AppStorage(Pref.secretLifetimeMinutes) private var secretLifetime = 5
    @AppStorage(Pref.detectRandomTokens) private var detectRandomTokens = true
    @AppStorage(Pref.clearAfterSecretPaste) private var clearAfterPaste = true
    @AppStorage(Pref.ignoredApps) private var ignoredAppsRaw = ""
    @State private var selectedApp: String?

    private var ignoredApps: [String] { Pref.ignoredAppIDs(from: ignoredAppsRaw) }

    var body: some View {
        Form {
            Section {
                Toggle(isOn: $skipConcealed) {
                    Text("Skip items from password managers")
                    Text("Apps like 1Password and Bitwarden mark copied passwords so clipboard managers can skip them.")
                }
            }

            Section {
                Picker("When a copy looks like a password or key", selection: $secretHandling) {
                    ForEach(SecretHandling.allCases) { handling in
                        Text(handling.label).tag(handling)
                    }
                }
                if secretHandling == .hide {
                    Picker("Delete hidden items after", selection: $secretLifetime) {
                        Text("1 minute").tag(1)
                        Text("5 minutes").tag(5)
                        Text("15 minutes").tag(15)
                        Text("1 hour").tag(60)
                        Text("Never").tag(0)
                    }
                }
                if secretHandling != .keep {
                    Toggle(isOn: $detectRandomTokens) {
                        Text("Also detect random-looking passwords")
                        Text("Catches generated passwords and keys without a known format. Might flag some ordinary codes.")
                    }
                }
                Toggle("Clear the clipboard after pasting a secret", isOn: $clearAfterPaste)
            } header: {
                Text("Secrets")
            } footer: {
                Text("Tuck recognizes API keys, access tokens, private keys and card numbers. Detection runs on your Mac.")
                    .settingsFootnote()
            }

            Section {
                IgnoredAppsList(apps: ignoredApps, selection: $selectedApp)
                HStack(spacing: 0) {
                    Button { addApps() } label: {
                        Image(systemName: "plus").frame(width: 22, height: 18)
                    }
                    .help("Add an app")
                    Divider().frame(height: 16)
                    Button { removeSelectedApp() } label: {
                        Image(systemName: "minus").frame(width: 22, height: 18)
                    }
                    .disabled(selectedApp == nil)
                    .help("Remove the selected app")
                    Spacer()
                }
                .buttonStyle(.borderless)
            } header: {
                Text("Ignored apps")
            } footer: {
                Text("Nothing you copy in these apps is saved.")
                    .settingsFootnote()
            }
        }
        .formStyle(.grouped)
        .frame(height: 590)
    }

    private func addApps() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = true
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.prompt = "Ignore"
        guard panel.runModal() == .OK else { return }
        var apps = ignoredApps
        for url in panel.urls {
            if let id = Bundle(url: url)?.bundleIdentifier, !apps.contains(id) {
                apps.append(id)
            }
        }
        ignoredAppsRaw = apps.joined(separator: "\n")
    }

    private func removeSelectedApp() {
        guard let selectedApp else { return }
        ignoredAppsRaw = ignoredApps.filter { $0 != selectedApp }.joined(separator: "\n")
        self.selectedApp = nil
    }
}

private struct IgnoredAppsList: View {
    let apps: [String]
    @Binding var selection: String?

    var body: some View {
        if apps.isEmpty {
            Text("No ignored apps")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 60)
        } else {
            List(apps, id: \.self, selection: $selection) { bundleID in
                let app = AppInfo.lookup(bundleID)
                HStack(spacing: 8) {
                    if let icon = app.icon {
                        Image(nsImage: icon).resizable().frame(width: 20, height: 20)
                    } else {
                        Image(systemName: "app.dashed").frame(width: 20, height: 20)
                    }
                    VStack(alignment: .leading, spacing: 0) {
                        Text(app.name)
                        if app.name != bundleID {
                            Text(bundleID)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.vertical, 2)
            }
            .frame(height: 140)
        }
    }
}

// MARK: - About

private struct AboutSettings: View {
    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "–"
        let build = info?["CFBundleVersion"] as? String ?? "–"
        return "Version \(short) (\(build))"
    }

    var body: some View {
        VStack(spacing: 10) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 72, height: 72)
            Text("Tuck")
                .font(.system(size: 20, weight: .bold))
            Text(version)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
            Text("A free, open-source clipboard manager.\nEverything stays on your Mac: no network, no telemetry.")
                .font(.system(size: 12))
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
            Text("Copyright © 2026 Aswin Ravichandran. MIT License.")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        .padding(32)
        .frame(maxWidth: .infinity)
        .frame(height: 300)
    }
}

private extension Text {
    func settingsFootnote() -> some View {
        font(.system(size: 11)).foregroundStyle(.secondary)
    }
}
