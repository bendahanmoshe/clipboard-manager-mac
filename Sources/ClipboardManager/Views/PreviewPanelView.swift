import SwiftUI

// MARK: - PreviewPanelView

struct PreviewPanelView: View {
    @ObservedObject var viewModel: ClipboardViewModel
    var onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            if let item = viewModel.selectedItem {
                previewHeader(item)
                Divider()
                previewContent(item)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                Divider()
                metaSection(item)
                Divider()
                actionBar(item)
            } else {
                emptyState
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor).opacity(0.25))
    }

    // MARK: - Header

    private func previewHeader(_ item: ClipboardItem) -> some View {
        HStack(spacing: 6) {
            Image(systemName: item.type.systemImage)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
            Text(item.type.displayName)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
            Spacer()
            if item.isPinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.orange)
            }
            if item.isFavorite {
                Image(systemName: "star.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.yellow)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Content preview

    @ViewBuilder
    private func previewContent(_ item: ClipboardItem) -> some View {
        switch item.type {

        case .image, .screenshot:
            if let data = item.imageData, let img = NSImage(data: data) {
                Image(nsImage: img)
                    .resizable()
                    .scaledToFit()
                    .padding(12)
            } else {
                placeholderIcon(item)
            }

        case .text, .richText:
            ScrollView {
                Text(item.previewText ?? "")
                    .font(.system(size: 11.5))
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
            }

        case .link:
            VStack(spacing: 14) {
                Image(systemName: "link.circle.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.green)
                Text(item.text ?? "")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .textSelection(.enabled)
                    .padding(.horizontal, 14)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .file:
            VStack(spacing: 10) {
                Image(systemName: "folder.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.orange)
                VStack(spacing: 4) {
                    ForEach(item.filePaths ?? [], id: \.self) { path in
                        Text(URL(fileURLWithPath: path).lastPathComponent)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        default:
            placeholderIcon(item)
        }
    }

    private func placeholderIcon(_ item: ClipboardItem) -> some View {
        VStack(spacing: 8) {
            Image(systemName: item.type.systemImage)
                .font(.system(size: 36))
                .foregroundStyle(.quaternary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Metadata

    private func metaSection(_ item: ClipboardItem) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if let app = item.sourceAppName {
                metaRow("app.badge", value: app)
            }
            metaRow("clock",     value: item.timestamp.formatted(date: .abbreviated, time: .shortened))
            metaRow("hand.tap",  value: "\(item.accessCount) use\(item.accessCount == 1 ? "" : "s")")
            categoryPickerRow(item)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
    }

    private func categoryPickerRow(_ item: ClipboardItem) -> some View {
        let assigned = viewModel.categories.first { $0.id.uuidString == item.categoryId }
        return HStack(spacing: 6) {
            Image(systemName: "tag")
                .font(.system(size: 9))
                .foregroundStyle(.quaternary)
                .frame(width: 12)

            Menu {
                Button {
                    viewModel.assignCategory(nil, to: item)
                } label: {
                    Label("No Category", systemImage: "xmark.circle")
                }
                Divider()
                ForEach(viewModel.categories.filter { !$0.isSystem }) { cat in
                    Button {
                        viewModel.assignCategory(cat, to: item)
                    } label: {
                        Label(cat.name, systemImage: cat.icon)
                    }
                }
            } label: {
                Text(assigned?.name ?? "No Category")
                    .font(.system(size: 10))
                    .foregroundStyle(assigned.map { AnyShapeStyle($0.color) } ?? AnyShapeStyle(.tertiary))
                    .lineLimit(1)
                    .underline(color: .clear)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
    }

    private func metaRow(_ icon: String, value: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 9))
                .foregroundStyle(.quaternary)
                .frame(width: 12)
            Text(value)
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
    }

    // MARK: - Action bar

    private func actionBar(_ item: ClipboardItem) -> some View {
        HStack(spacing: 6) {
            actionButton("Copy",   icon: "doc.on.doc.fill",  tint: .accentColor) { viewModel.copyItem(item) }
            actionButton("Paste",  icon: "arrow.down.doc",   tint: .green)       { viewModel.pasteItem(item) { onDismiss() } }
            actionButton(
                item.isPinned ? "Unpin" : "Pin",
                icon: item.isPinned ? "pin.slash" : "pin.fill",
                tint: .orange
            ) { viewModel.togglePin(item) }
            actionButton(
                item.isFavorite ? "Unfav" : "Fav",
                icon: item.isFavorite ? "star.slash" : "star.fill",
                tint: .yellow
            ) { viewModel.toggleFavorite(item) }
            actionButton("Delete", icon: "trash.fill",        tint: .red)         { viewModel.deleteItem(item) }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
    }

    private func actionButton(_ label: String, icon: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundStyle(tint)
                Text(label)
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "cursorarrow.click")
                .font(.system(size: 28))
                .foregroundStyle(.quaternary)
            Text("Select an item")
                .font(.system(size: 11))
                .foregroundStyle(.quaternary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
