import SwiftUI

// MARK: - SidebarView

struct SidebarView: View {
    @ObservedObject var viewModel: ClipboardViewModel

    var body: some View {
        VStack(spacing: 0) {
            appHeader
            Divider()
            categoryList
            Spacer(minLength: 0)
            Divider()
            footer
        }
    }

    // MARK: - App header

    private var appHeader: some View {
        HStack(spacing: 8) {
            Image(systemName: "doc.on.clipboard.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.accentColor)
            Text("Clipboard")
                .font(.system(size: 14, weight: .semibold))
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
    }

    // MARK: - Category list

    private var categoryList: some View {
        ScrollView {
            VStack(spacing: 2) {
                ForEach(viewModel.categories) { cat in
                    CategoryRow(
                        category: cat,
                        isSelected: viewModel.selectedCategory.id == cat.id
                    ) {
                        viewModel.selectedCategory = cat
                    }
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 6)
        }
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 0) {
            monitoringToggle
                .padding(.horizontal, 8)
                .padding(.top, 8)
            settingsButton
                .padding(.horizontal, 8)
                .padding(.bottom, 10)
        }
    }

    private var monitoringToggle: some View {
        Button {
            ClipboardMonitor.shared.toggle()
            // Nudge SwiftUI to re-render
            viewModel.objectWillChange.send()
        } label: {
            HStack(spacing: 7) {
                Circle()
                    .fill(ClipboardMonitor.shared.isMonitoring ? Color.green : Color.orange)
                    .frame(width: 7, height: 7)
                Text(ClipboardMonitor.shared.isMonitoring ? "Monitoring" : "Paused")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }

    private var settingsButton: some View {
        Button {
            viewModel.showSettings = true
        } label: {
            HStack(spacing: 7) {
                Image(systemName: "gear")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                Text("Settings")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - CategoryRow

private struct CategoryRow: View {
    let category: ClipboardCategory
    let isSelected: Bool
    let onSelect: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 8) {
                Image(systemName: category.icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(isSelected ? .white : category.color)
                    .frame(width: 18)

                Text(category.name)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? .white : .primary)
                    .lineLimit(1)

                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(rowBackground)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }

    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: 7, style: .continuous)
            .fill(
                isSelected
                    ? AnyShapeStyle(category.color)
                    : isHovered
                        ? AnyShapeStyle(Color(NSColor.controlBackgroundColor))
                        : AnyShapeStyle(Color.clear)
            )
    }
}
