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
            // TODO: replace the system symbol with the Tuck menu bar template glyph.
            if model.queue.isEmpty {
                Image(systemName: model.isPaused ? "tray" : "tray.full")
            } else {
                Image(systemName: "tray.and.arrow.down.fill")
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

    var body: some View {
        Button("Open Tuck") { model.showPopup() }
        Toggle("Pause Recording", isOn: $model.isPaused)
        Divider()
        Section("Paste Queue") {
            Toggle("Collect New Copies", isOn: $model.isCollecting)
            Button(model.queue.isEmpty ? "Paste Next" : "Paste Next (\(model.queue.count) left)") {
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
