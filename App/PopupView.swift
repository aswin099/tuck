import SwiftUI
import TuckCore

extension Color {
    /// Tuck indigo (#2B2D6E) in light mode, periwinkle (#8E94F2) in dark mode.
    static let tuckAccent = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(red: 0.557, green: 0.580, blue: 0.949, alpha: 1)
            : NSColor(red: 0.169, green: 0.176, blue: 0.431, alpha: 1)
    })
    /// Amber (#FFB547), used only for the pin marker.
    static let tuckAmber = Color(red: 1.0, green: 0.71, blue: 0.28)
}

struct PopupView: View {
    @EnvironmentObject private var model: AppModel
    @FocusState private var searchFocused: Bool
    @AppStorage(Pref.showKeyHints) private var showKeyHints = true

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                searchField
                Divider()
                if !model.queue.isEmpty || model.isCollecting {
                    QueueBanner()
                    Divider()
                }
                list
                if showKeyHints {
                    Divider()
                    footer
                }
            }
            .frame(width: AppModel.listWidth)

            if model.showPreview {
                Divider()
                PreviewPane(item: model.selectedItem)
                    .frame(width: AppModel.previewWidth)
            }
        }
        .frame(width: model.popupWidth, height: PopupPanel.height)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .onAppear { searchFocused = true }
        .onChange(of: model.focusToken) { _, _ in searchFocused = true }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search clipboard", text: $model.query)
                .textFieldStyle(.plain)
                .font(.system(size: 15))
                .focused($searchFocused)
                .onSubmit { model.pasteSelected() }
                .onKeyPress(.downArrow) { model.move(1); return .handled }
                .onKeyPress(.upArrow) { model.move(-1); return .handled }
                .onKeyPress(.escape) { model.hidePopup(); return .handled }
                .onKeyPress(.tab) { model.toggleQueuedSelected(); return .handled }
                .onKeyPress(keys: [.delete]) { press in
                    guard press.modifiers.contains(.command) else { return .ignored }
                    model.deleteSelected()
                    return .handled
                }
                .onKeyPress(characters: .decimalDigits) { press in
                    guard press.modifiers == .command,
                          let number = Int(press.characters), number >= 1 else { return .ignored }
                    model.paste(at: number - 1)
                    return .handled
                }
                .onKeyPress(characters: CharacterSet(charactersIn: "pPyY")) { press in
                    guard press.modifiers == .command else { return .ignored }
                    if press.characters.lowercased() == "p" {
                        model.togglePinSelected()
                    } else {
                        model.showPreview.toggle()
                    }
                    return .handled
                }
            if !model.query.isEmpty {
                Button {
                    model.query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .help("Clear search")
            }
            Button {
                model.showPreview.toggle()
            } label: {
                Image(systemName: "sidebar.right")
                    .foregroundStyle(model.showPreview ? Color.tuckAccent : Color.secondary)
            }
            .buttonStyle(.plain)
            .help(model.showPreview ? "Hide preview (⌘Y)" : "Show preview (⌘Y)")
        }
        .padding(.horizontal, 14)
        .frame(height: 44)
    }

    private var list: some View {
        Group {
            if model.visibleItems.isEmpty {
                EmptyState(isSearching: !model.query.isEmpty)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 2) {
                            ForEach(Array(model.visibleItems.enumerated()), id: \.element.id) { index, item in
                                ItemRow(
                                    item: item,
                                    index: index,
                                    isSelected: item.id == model.selection,
                                    queuePosition: model.queue.position(of: item)
                                )
                                .id(item.id)
                                .onTapGesture(count: 2) { model.paste(item) }
                                .onTapGesture { model.selection = item.id }
                            }
                        }
                        .padding(8)
                    }
                    .onChange(of: model.selection) { _, id in
                        if let id { proxy.scrollTo(id) }
                    }
                }
            }
        }
        .frame(maxHeight: .infinity)
    }

    private var footer: some View {
        HStack(spacing: 12) {
            KeyHint(key: "↩", label: "paste")
            KeyHint(key: "⇥", label: "queue")
            KeyHint(key: "⌘Y", label: "preview")
            KeyHint(key: "⌘P", label: "pin")
            KeyHint(key: "⌘⌫", label: "delete")
        }
        .frame(maxWidth: .infinity)
        .frame(height: 28)
    }
}

private struct KeyHint: View {
    let key: String
    let label: String

    var body: some View {
        HStack(spacing: 3) {
            Text(key).fontWeight(.medium)
            Text(label)
        }
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
        .fixedSize()
    }
}

private struct EmptyState: View {
    let isSearching: Bool

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: isSearching ? "magnifyingglass" : "doc.on.clipboard")
                .font(.system(size: 24, weight: .light))
                .foregroundStyle(.tertiary)
            Text(isSearching ? "No matches" : "Nothing copied yet")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
            if !isSearching {
                Text("Copy something and it will show up here.")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Shown above the list while the paste queue has items or is collecting copies.
private struct QueueBanner: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: model.isCollecting ? "record.circle" : "list.number")
                .foregroundStyle(Color.tuckAccent)
                .symbolEffect(.pulse, isActive: model.isCollecting)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                Text("⌃⌘V pastes the next one")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 4)
            Button(model.isCollecting ? "Stop" : "Collect") {
                model.isCollecting.toggle()
            }
            .controlSize(.small)
            .help(model.isCollecting ? "Stop adding new copies to the queue" : "Add every new copy to the queue")
            Button("Clear") { model.clearQueue() }
                .controlSize(.small)
                .disabled(model.queue.isEmpty)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private var title: String {
        let count = model.queue.count
        let items = count == 1 ? "1 item" : "\(count) items"
        return model.isCollecting ? "Collecting copies · \(items) queued" : "\(items) in paste queue"
    }
}

struct ItemRow: View {
    let item: ClipItem
    let index: Int
    let isSelected: Bool
    let queuePosition: Int?

    @AppStorage(Pref.showMetadata) private var showMetadata = true
    @AppStorage(Pref.rowLines) private var rowLines = 2

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(item.isPinned ? Color.tuckAmber : Color.clear)
                .frame(width: 6, height: 6)
                .accessibilityLabel(item.isPinned ? "Pinned" : "")
            content
            Spacer(minLength: 4)
            if let queuePosition {
                Text("\(queuePosition)")
                    .font(.system(size: 10, weight: .semibold).monospacedDigit())
                    .foregroundStyle(Color(nsColor: .windowBackgroundColor))
                    .frame(minWidth: 16, minHeight: 16)
                    .background(Circle().fill(Color.tuckAccent))
                    .help("Position \(queuePosition) in the paste queue")
            }
            if index < 9 {
                Text("⌘\(index + 1)")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .frame(minHeight: 36)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isSelected ? Color.tuckAccent.opacity(0.16) : Color.clear)
        )
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var content: some View {
        VStack(alignment: .leading, spacing: 2) {
            if item.kind == .image, let image = ImageCache.image(for: item) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 48, height: 32)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            } else {
                HStack(spacing: 4) {
                    if item.isSecret {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    Text(item.displayPreview)
                        .font(.system(size: 13))
                        .lineLimit(rowLines)
                        .truncationMode(.tail)
                }
            }
            if showMetadata {
                ItemMetadata(item: item)
            }
        }
    }
}

/// Source app icon and name plus how long ago the item was copied.
private struct ItemMetadata: View {
    let item: ClipItem

    var body: some View {
        HStack(spacing: 4) {
            if let bundleID = item.sourceApp {
                let app = AppInfo.lookup(bundleID)
                if let icon = app.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 14, height: 14)
                }
                Text(app.name)
                Text("·")
            }
            Text(item.createdAt, format: .relative(presentation: .numeric, unitsStyle: .abbreviated))
        }
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
        .lineLimit(1)
    }
}
