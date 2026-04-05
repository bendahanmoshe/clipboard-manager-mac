import AppKit
import Combine

// MARK: - ClipboardMonitor

final class ClipboardMonitor: ObservableObject, @unchecked Sendable {
    static let shared = ClipboardMonitor()

    @Published var isMonitoring = true

    var onNewItem: ((ClipboardItem) -> Void)?

    private let pasteboard = NSPasteboard.general
    private var lastChangeCount: Int
    private var timer: Timer?

    // Apps whose clipboard content we silently ignore
    private var blacklist: Set<String> = [
        "com.agilebits.onepassword7",
        "com.1password.1password",
        "com.apple.keychainaccess",
        "com.bitwarden.desktop"
    ]

    private init() {
        lastChangeCount = pasteboard.changeCount
    }

    // MARK: - Control

    func start() {
        guard timer == nil else { return }
        isMonitoring = true
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            
            
            self?.poll()
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    func stop() {
        isMonitoring = false
        timer?.invalidate()
        timer = nil
    }

    func toggle() { isMonitoring ? stop() : start() }

    func addToBlacklist(_ bundleId: String) { blacklist.insert(bundleId) }
    func removeFromBlacklist(_ bundleId: String) { blacklist.remove(bundleId) }

    // MARK: - Polling

    private func poll() {
        let count = pasteboard.changeCount
        guard count != lastChangeCount else { return }
        lastChangeCount = count

        if let app = NSWorkspace.shared.frontmostApplication,
           blacklist.contains(app.bundleIdentifier ?? "") { return }

        guard let item = extract() else { return }
        onNewItem?(item)
    }

    private func extract() -> ClipboardItem? {
        let app = NSWorkspace.shared.frontmostApplication
        let now = Date()

        // 1. Image / Screenshot
        if let data = imageFromPasteboard() {
            let isShot = isLikelyScreenshot(app)
            return ClipboardItem(
                id: UUID(), type: isShot ? .screenshot : .image,
                text: nil, imageData: data, filePaths: nil,
                sourceApp: app?.bundleIdentifier, sourceAppName: app?.localizedName,
                timestamp: now, isPinned: false, isFavorite: false,
                tags: [], categoryId: nil, accessCount: 0, lastAccessed: nil
            )
        }

        // 2. File URLs
        if let paths = filePathsFromPasteboard() {
            return ClipboardItem(
                id: UUID(), type: .file,
                text: nil, imageData: nil, filePaths: paths,
                sourceApp: app?.bundleIdentifier, sourceAppName: app?.localizedName,
                timestamp: now, isPinned: false, isFavorite: false,
                tags: [], categoryId: nil, accessCount: 0, lastAccessed: nil
            )
        }

        // 3. Text / Rich text / Link
        if let text = pasteboard.string(forType: .string), !text.isEmpty {
            let kind: ClipboardItemType = isURL(text) ? .link
                : (pasteboard.data(forType: .rtf) != nil ? .richText : .text)
            return ClipboardItem(
                id: UUID(), type: kind,
                text: text, imageData: nil, filePaths: nil,
                sourceApp: app?.bundleIdentifier, sourceAppName: app?.localizedName,
                timestamp: now, isPinned: false, isFavorite: false,
                tags: [], categoryId: nil, accessCount: 0, lastAccessed: nil
            )
        }

        return nil
    }

    // MARK: - Helpers

    private func imageFromPasteboard() -> Data? {
        // Try PNG first (preserves quality), then TIFF
        let types: [NSPasteboard.PasteboardType] = [.png, .tiff]
        for t in types {
            if let raw = pasteboard.data(forType: t),
               let img = NSImage(data: raw) {
                return thumbnail(img, maxDim: 1200)
            }
        }
        return nil
    }

    private func thumbnail(_ image: NSImage, maxDim: CGFloat) -> Data? {
        let s = image.size
        let scale = min(maxDim / max(s.width, s.height, 1), 1.0)
        let ns = NSSize(width: s.width * scale, height: s.height * scale)
        let out = NSImage(size: ns)
        out.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: ns),
                   from: NSRect(origin: .zero, size: s),
                   operation: .copy, fraction: 1)
        out.unlockFocus()
        guard let cg = out.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        return NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:])
    }

    private func filePathsFromPasteboard() -> [String]? {
        let opts: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
        guard let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: opts) as? [URL],
              !urls.isEmpty else { return nil }
        return urls.map(\.path)
    }

    private func isURL(_ text: String) -> Bool {
        let t = text.trimmingCharacters(in: .whitespaces)
        return (t.hasPrefix("http://") || t.hasPrefix("https://")) && !t.contains(" ")
    }

    private func isLikelyScreenshot(_ app: NSRunningApplication?) -> Bool {
        let screenshotBundleIDs: Set<String> = [
            "com.apple.screencaptureui",
            "com.apple.systemuiserver",
            "com.apple.ScreenSearch"
        ]
        return screenshotBundleIDs.contains(app?.bundleIdentifier ?? "")
    }
}
