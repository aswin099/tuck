import SwiftUI
import KeyboardShortcuts

@main
struct TuckApp: App {
    @StateObject private var model = AppModel.shared

    init() {
        AppModel.shared.start()
    }

    var body: some Scene {
        MenuBarExtra {
            MenuContent(model: model)
        } label: {
            // Template glyphs from Assets.xcassets (drawn by tools/render-icon.swift); dimmed while paused.
            Image(model.isPaused ? "MenuBarIconPaused" : "MenuBarIcon")
            if !model.queue.isEmpty {
                Text("\(model.queue.count)")
            }
        }
        Settings {
            SettingsView()
        }
    }
}

@MainActor
struct MenuContent: View {
    @ObservedObject var model: AppModel
    @AppStorage(Pref.autoPaste) private var autoPaste = false

    /// "Paste Next" when Tuck sends ⌘V, "Copy Next" when you press it yourself.
    private var nextTitle: String {
        let verb = autoPaste ? "Paste Next" : "Copy Next"
        return model.queue.isEmpty ? verb : "\(verb) (\(model.queue.count) left)"
    }

    var body: some View {
        Button("Open Tuck") { model.showPopup() }
        Toggle("Pause Recording", isOn: $model.isPaused)
        Divider()
        Section("Paste Queue") {
            Toggle("Collect New Copies", isOn: $model.isCollecting)
            Button(nextTitle) {
                model.pasteNextInQueue()
            }
            .disabled(model.queue.isEmpty)
            Button("Clear Queue") { model.clearQueue() }
                .disabled(model.queue.isEmpty && !model.isCollecting)
        }
        Divider()
        SettingsLink { Text("Settings…") }
            .keyboardShortcut(",")
        Button("Clear History…") { model.confirmClearHistory() }
        Divider()
        Button("Quit Tuck") { NSApplication.shared.terminate(nil) }
            .keyboardShortcut("q")
    }
}
