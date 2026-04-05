import Foundation
import Combine
import AppKit

@MainActor
final class ClipboardViewModel: ObservableObject {

    // MARK: Published state

    @Published var items: [ClipboardItem] = []
    @Published var searchQuery = ""
    @Published var selectedTypeFilter: ClipboardItemType? = nil
    @Published var selectedItem: ClipboardItem? = nil
    @Published var selectedCategory: ClipboardCategory = .all
    @Published var categories: [ClipboardCategory] = ClipboardCategory.defaults
    @Published var isLoading = false
    @Published var showSettings = false

    // MARK: Private

    private let storage = StorageService.shared
    private let monitor = ClipboardMonitor.shared
    private var cancellables = Set<AnyCancellable>()
    private var searchTask: Task<Void, Never>?

    // MARK: Init

    init() {
        setupMonitor()
        setupReactiveSearch()
        loadInitialItems()
    }

    // MARK: - Setup

    private func setupMonitor() {
        monitor.onNewItem = { [weak self] item in
            Task { @MainActor [weak self] in
                self?.ingest(item)
            }
        }
        monitor.start()
    }

    private func setupReactiveSearch() {
        Publishers.CombineLatest3($searchQuery, $selectedTypeFilter, $selectedCategory)
            .debounce(for: .milliseconds(120), scheduler: DispatchQueue.main)
            .removeDuplicates { $0 == $1 }
            .sink { [weak self] query, type, cat in
                self?.search(query: query, type: type, category: cat)
            }
            .store(in: &cancellables)
    }

    private func loadInitialItems() {
        isLoading = true
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            let fetched = self.storage.fetchAll(limit: 200)
            await MainActor.run {
                self.items = fetched
                self.selectedItem = fetched.first
                self.isLoading = false
            }
        }
    }

    // MARK: - Search

    private func search(query: String, type: ClipboardItemType?, category: ClipboardCategory) {
        searchTask?.cancel()
        searchTask = Task.detached(priority: .userInitiated) { [weak self] in
            guard let self, !Task.isCancelled else { return }

            let results: [ClipboardItem]
            if category.id == ClipboardCategory.favoritesID {
                results = self.storage.fetchFavorites()
            } else if category.id == ClipboardCategory.pinnedID {
                results = self.storage.fetchPinned()
            } else if category.isSystem {
                // "All Items" — no category filter
                results = self.storage.search(query: query, type: type, limit: 200)
            } else {
                // Custom category (Work, Personal, Real Estate, …)
                results = self.storage.search(query: query, type: type,
                                              categoryId: category.id.uuidString, limit: 200)
            }

            guard !Task.isCancelled else { return }
            await MainActor.run {
                self.items = results
                if let sel = self.selectedItem, !results.contains(sel) {
                    self.selectedItem = results.first
                }
            }
        }
    }

    // MARK: - Category assignment

    func assignCategory(_ category: ClipboardCategory?, to item: ClipboardItem) {
        guard let idx = items.firstIndex(of: item) else { return }
        let newId = category?.id.uuidString
        items[idx].categoryId = newId
        storage.updateCategory(id: item.id, categoryId: newId)

        // If viewing a custom category and this item no longer belongs, remove it
        if !selectedCategory.isSystem,
           selectedCategory.id.uuidString != (newId ?? "") {
            items.remove(at: idx)
            if selectedItem == item { selectedItem = items.first }
        }
    }

    // MARK: - Ingest new clipboard item

    private func ingest(_ item: ClipboardItem) {
        // Deduplicate against the most recent item
        if let top = items.first, isDuplicate(item, of: top) { return }

        storage.insert(item)

        // Prepend only if not filtering
        if searchQuery.isEmpty && selectedTypeFilter == nil &&
           selectedCategory.id == ClipboardCategory.allID {
            items.insert(item, at: 0)
            if items.count > 200 { items = Array(items.prefix(200)) }
        }
    }

    private func isDuplicate(_ a: ClipboardItem, of b: ClipboardItem) -> Bool {
        guard a.type == b.type else { return false }
        switch a.type {
        case .text, .richText, .link: return a.text == b.text
        case .file: return a.filePaths == b.filePaths
        default: return false
        }
    }

    // MARK: - Actions

    func copyItem(_ item: ClipboardItem) {
        let pb = NSPasteboard.general
        pb.clearContents()
        switch item.type {
        case .text, .richText, .link:
            if let t = item.text { pb.setString(t, forType: .string) }
        case .image, .screenshot:
            if let d = item.imageData, let img = NSImage(data: d) { pb.writeObjects([img]) }
        case .file:
            if let paths = item.filePaths {
                pb.writeObjects(paths.map { URL(fileURLWithPath: $0) } as [NSURL])
            }
        case .unknown: break
        }
        storage.incrementAccess(id: item.id)
    }

    func pasteItem(_ item: ClipboardItem, hideWindow: (() -> Void)? = nil) {
        copyItem(item)
        hideWindow?()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            PasteService.shared.paste()
        }
    }

    func deleteItem(_ item: ClipboardItem) {
        storage.delete(id: item.id)
        if let idx = items.firstIndex(of: item) { items.remove(at: idx) }
        if selectedItem == item { selectedItem = items.first }
    }

    func togglePin(_ item: ClipboardItem) {
        guard let idx = items.firstIndex(of: item) else { return }
        items[idx].isPinned.toggle()
        storage.update(id: item.id, isPinned: items[idx].isPinned)
    }

    func toggleFavorite(_ item: ClipboardItem) {
        guard let idx = items.firstIndex(of: item) else { return }
        items[idx].isFavorite.toggle()
        storage.update(id: item.id, isFavorite: items[idx].isFavorite)
    }

    func addTag(_ tag: String, to item: ClipboardItem) {
        guard let idx = items.firstIndex(of: item), !items[idx].tags.contains(tag) else { return }
        items[idx].tags.append(tag)
        storage.update(id: item.id, tags: items[idx].tags)
    }

    func clearAll() {
        storage.cleanup(maxItems: 0)
        items.removeAll()
        selectedItem = nil
    }

    func selectNext() {
        guard !items.isEmpty else { return }
        if let sel = selectedItem, let idx = items.firstIndex(of: sel) {
            selectedItem = items[min(idx + 1, items.count - 1)]
        } else {
            selectedItem = items.first
        }
    }

    func selectPrevious() {
        guard !items.isEmpty else { return }
        if let sel = selectedItem, let idx = items.firstIndex(of: sel) {
            selectedItem = items[max(idx - 1, 0)]
        } else {
            selectedItem = items.first
        }
    }
}
