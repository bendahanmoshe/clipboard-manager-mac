import SwiftUI

// MARK: - ClipboardListView

struct ClipboardListView: View {
    @ObservedObject var viewModel: ClipboardViewModel
    var onDismiss: () -> Void

    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            SearchBarView(query: $viewModel.searchQuery, isFocused: $searchFocused)
                .padding(.horizontal, 12)
                .padding(.top, 12)
                .padding(.bottom, 6)

            TypeFilterBar(selected: $viewModel.selectedTypeFilter)
                .padding(.horizontal, 12)
                .padding(.bottom, 6)

            Divider()

            Group {
                if viewModel.isLoading {
                    loadingView
                } else if viewModel.items.isEmpty {
                    emptyView
                } else {
                    itemList
                }
            }

            Divider()
            statusBar
        }
        .onAppear { searchFocused = true }
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: 10) {
            Spacer()
            ProgressView()
                .scaleEffect(0.8)
            Text("Loading history…")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    // MARK: - Empty

    private var emptyView: some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: viewModel.searchQuery.isEmpty ? "tray" : "magnifyingglass")
                .font(.system(size: 30))
                .foregroundStyle(.quaternary)
            Text(
                viewModel.searchQuery.isEmpty
                    ? "Nothing copied yet"
                    : "No results for \"\(viewModel.searchQuery)\""
            )
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
            Spacer()
        }
    }

    // MARK: - Item list

    private var itemList: some View {
        ScrollViewReader { proxy in
            List(viewModel.items, selection: $viewModel.selectedItem) { item in
                ClipboardRowView(item: item, viewModel: viewModel, onDismiss: onDismiss)
                    .id(item.id)
                    .tag(item)
                    .listRowInsets(EdgeInsets(top: 1, leading: 6, bottom: 1, trailing: 6))
                    .listRowBackground(rowBackground(for: item))
                    .listRowSeparator(.hidden)
            }
            .listStyle(.plain)
            .onChange(of: viewModel.selectedItem) { _, sel in
                if let sel {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        proxy.scrollTo(sel.id, anchor: .center)
                    }
                }
            }
        }
    }

    // MARK: - Status bar

    private var statusBar: some View {
        HStack(spacing: 6) {
            Text(viewModel.items.isEmpty ? "Empty" : "\(viewModel.items.count) items")
                .font(.system(size: 10))
                .foregroundStyle(.quaternary)

            Spacer()

            if !viewModel.searchQuery.isEmpty {
                Button("Clear search") { viewModel.searchQuery = "" }
                    .buttonStyle(.plain)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
    }

    // MARK: - Helpers

    @ViewBuilder
    private func rowBackground(for item: ClipboardItem) -> some View {
        if viewModel.selectedItem == item {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Color.accentColor.opacity(0.13))
        } else {
            Color.clear
        }
    }
}

// MARK: - TypeFilterBar

struct TypeFilterBar: View {
    @Binding var selected: ClipboardItemType?

    private struct FilterItem: Identifiable {
        let id = UUID()
        let label: String
        let icon: String
        let type: ClipboardItemType?
    }

    private let filters: [FilterItem] = [
        FilterItem(label: "All",        icon: "tray.full",      type: nil),
        FilterItem(label: "Text",       icon: "doc.text",       type: .text),
        FilterItem(label: "Images",     icon: "photo",          type: .image),
        FilterItem(label: "Links",      icon: "link",           type: .link),
        FilterItem(label: "Files",      icon: "folder",         type: .file),
        FilterItem(label: "Shots",      icon: "camera.viewfinder", type: .screenshot),
    ]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 5) {
                ForEach(filters) { f in
                    FilterChip(
                        label: f.label,
                        icon: f.icon,
                        isSelected: selected == f.type
                    ) {
                        selected = f.type
                    }
                }
            }
        }
    }
}

// MARK: - FilterChip

private struct FilterChip: View {
    let label: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .medium))
                Text(label)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(
                Capsule(style: .continuous)
                    .fill(isSelected ? Color.accentColor : Color(NSColor.controlBackgroundColor))
            )
            .foregroundStyle(isSelected ? .white : .secondary)
        }
        .buttonStyle(.plain)
    }
}
