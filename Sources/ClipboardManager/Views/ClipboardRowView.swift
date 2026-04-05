import SwiftUI

// MARK: - ClipboardRowView

struct ClipboardRowView: View {
    let item: ClipboardItem
    @ObservedObject var viewModel: ClipboardViewModel
    var onDismiss: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 10) {
            typeIcon
            content
            Spacer(minLength: 4)
            trailingArea
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.1), value: isHovered)
        .onTapGesture { viewModel.selectedItem = item }
        .onTapGesture(count: 2) { viewModel.pasteItem(item) { onDismiss() } }
    }

    // MARK: - Type icon

    private var typeIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(iconTint.opacity(0.12))
                .frame(width: 34, height: 34)

            // Show thumbnail for images
            if (item.type == .image || item.type == .screenshot),
               let data = item.imageData,
               let img = NSImage(data: data) {
                Image(nsImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 34, height: 34)
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            } else {
                Image(systemName: item.type.systemImage)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(iconTint)
            }
        }
    }

    // MARK: - Content

    private var content: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(item.displayTitle)
                .font(.system(size: 12, weight: .medium))
                .lineLimit(2)
                .foregroundStyle(.primary)

            HStack(spacing: 5) {
                if let app = item.sourceAppName {
                    Text(app)
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
                Text("·")
                    .font(.system(size: 10))
                    .foregroundStyle(.quaternary)
                Text(item.timestamp, style: .relative)
                    .font(.system(size: 10))
                    .foregroundStyle(.quaternary)
            }
        }
    }

    // MARK: - Trailing area

    @ViewBuilder
    private var trailingArea: some View {
        if isHovered {
            HStack(spacing: 3) {
                actionBtn("pin.fill",   tint: item.isPinned   ? .orange : Color(NSColor.tertiaryLabelColor)) { viewModel.togglePin(item) }
                actionBtn("star.fill",  tint: item.isFavorite ? .yellow : Color(NSColor.tertiaryLabelColor)) { viewModel.toggleFavorite(item) }
                actionBtn("trash",      tint: .red.opacity(0.8))                                              { viewModel.deleteItem(item) }
            }
            .transition(.opacity.combined(with: .scale(scale: 0.9)))
        } else {
            // Always-visible indicators
            HStack(spacing: 3) {
                if item.isPinned   { Image(systemName: "pin.fill").font(.system(size: 9)).foregroundStyle(.orange) }
                if item.isFavorite { Image(systemName: "star.fill").font(.system(size: 9)).foregroundStyle(.yellow) }
            }
            .frame(minWidth: 14)
        }
    }

    // MARK: - Helpers

    private func actionBtn(_ icon: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(tint)
                .frame(width: 24, height: 24)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.7))
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var iconTint: Color {
        switch item.type {
        case .text:       return .blue
        case .richText:   return .purple
        case .image:      return .teal
        case .screenshot: return .indigo
        case .file:       return .orange
        case .link:       return .green
        case .unknown:    return .gray
        }
    }
}
