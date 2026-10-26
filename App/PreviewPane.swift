import SwiftUI
import TuckCore

/// Right-hand pane in the popup showing the full selected item and its details.
struct PreviewPane: View {
    let item: ClipItem?

    @State private var revealSecret = false

    var body: some View {
        Group {
            if let item {
                VStack(alignment: .leading, spacing: 0) {
                    header(item)
                    Divider()
                    content(item)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    Divider()
                    details(item)
                }
            } else {
                Text("No item selected")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onChange(of: item?.id) { _, _ in revealSecret = false }
    }

    private func header(_ item: ClipItem) -> some View {
        HStack(spacing: 6) {
            Image(systemName: item.symbolName)
                .foregroundStyle(.secondary)
            Text(item.secretKind?.label ?? item.kindLabel)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            Spacer()
            if item.isPinned {
                Label("Pinned", systemImage: "pin.fill")
                    .labelStyle(.iconOnly)
                    .foregroundStyle(Color.tuckAmber)
                    .help("Pinned")
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 44)
    }

    @ViewBuilder
    private func content(_ item: ClipItem) -> some View {
        switch item.kind {
        case .image:
            if let image = ImageCache.image(for: item) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .padding(14)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        case .file:
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(item.filePaths, id: \.self) { path in
                        HStack(spacing: 8) {
                            Image(nsImage: NSWorkspace.shared.icon(forFile: path))
                                .resizable()
                                .frame(width: 28, height: 28)
                            VStack(alignment: .leading, spacing: 1) {
                                Text((path as NSString).lastPathComponent)
                                    .font(.system(size: 13))
                                    .lineLimit(1)
                                Text((path as NSString).deletingLastPathComponent)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                        }
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        case .text, .link:
            if item.isSecret && !revealSecret {
                VStack(spacing: 10) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 22, weight: .light))
                        .foregroundStyle(.tertiary)
                    Text("Hidden because it looks like a secret")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Show") { revealSecret = true }
                        .controlSize(.small)
                }
                .padding(14)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    Text(item.text ?? "")
                        .font(.system(size: 12, design: item.looksLikeCode ? .monospaced : .default))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                }
            }
        }
    }

    private func details(_ item: ClipItem) -> some View {
        Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 4) {
            if let bundleID = item.sourceApp {
                let app = AppInfo.lookup(bundleID)
                detailRow("Source") {
                    HStack(spacing: 4) {
                        if let icon = app.icon {
                            Image(nsImage: icon).resizable().frame(width: 14, height: 14)
                        }
                        Text(app.name)
                    }
                }
            }
            detailRow("Copied") {
                Text(item.createdAt, format: .relative(presentation: .named))
            }
            if let size = item.sizeDescription {
                detailRow("Size") { Text(size) }
            }
            if let expiresAt = item.expiresAt {
                detailRow("Deletes") {
                    Text(expiresAt, format: .relative(presentation: .named))
                }
            }
        }
        .font(.system(size: 11))
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func detailRow<Value: View>(_ label: String, @ViewBuilder value: () -> Value) -> some View {
        GridRow {
            Text(label)
                .foregroundStyle(.secondary)
                .gridColumnAlignment(.trailing)
            value()
                .lineLimit(1)
        }
    }
}

extension ClipItem {
    var kindLabel: String {
        switch kind {
        case .text: return "Text"
        case .link: return "Link"
        case .image: return "Image"
        case .file: return filePaths.count == 1 ? "File" : "Files"
        }
    }

    var symbolName: String {
        if isSecret { return "lock" }
        switch kind {
        case .text: return "text.alignleft"
        case .link: return "link"
        case .image: return "photo"
        case .file: return "doc"
        }
    }

    var filePaths: [String] {
        (text ?? "").split(separator: "\n").map(String.init)
    }

    /// Rough guess used to pick a monospaced font in the preview.
    var looksLikeCode: Bool {
        guard let text else { return false }
        let markers = ["{", "}", ";", "=>", "func ", "def ", "const ", "</", "#include", "import "]
        return markers.filter { text.contains($0) }.count >= 2
    }

    @MainActor
    var sizeDescription: String? {
        switch kind {
        case .text, .link:
            let text = text ?? ""
            let words = text.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
            let lines = text.split(whereSeparator: \.isNewline).count
            var parts = ["\(text.count) characters"]
            if words > 1 { parts.append("\(words) words") }
            if lines > 1 { parts.append("\(lines) lines") }
            return parts.joined(separator: " · ")
        case .image:
            guard let data else { return nil }
            let bytes = ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file)
            if let rep = ImageCache.image(for: self)?.representations.first {
                return "\(rep.pixelsWide) × \(rep.pixelsHigh) px · \(bytes)"
            }
            return bytes
        case .file:
            let count = filePaths.count
            return count == 1 ? "1 item" : "\(count) items"
        }
    }
}
