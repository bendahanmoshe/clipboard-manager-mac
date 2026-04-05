import AppKit
import SwiftUI

// MARK: - AppDelegate

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem!
    private var panel: FloatingPanel!
    private var hostingController: NSHostingController<MainPanelView>!
    private var eventMonitor: Any?
    var viewModel: ClipboardViewModel!

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        viewModel = ClipboardViewModel()
        setupMenuBar()
        setupPanel()
        setupHotkey()
        setupKeyMonitor()
    }

    func applicationWillTerminate(_ notification: Notification) {
        HotkeyService.shared.unregister()
        if let m = eventMonitor { NSEvent.removeMonitor(m) }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    // MARK: - Menu bar

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        guard let btn = statusItem.button else { return }
        btn.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "Clipboard Manager")
        btn.image?.isTemplate = true
        btn.action = #selector(statusItemClicked(_:))
        btn.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { togglePanel(); return }
        if event.type == .rightMouseUp {
            let menu = NSMenu()
            menu.addItem(makeItem("Open Clipboard Manager", action: #selector(showPanel)))
            menu.addItem(.separator())
            menu.addItem(makeItem(ClipboardMonitor.shared.isMonitoring ? "Pause Monitoring" : "Resume Monitoring",
                                  action: #selector(toggleMonitoring)))
            menu.addItem(makeItem("Settings…", action: #selector(openSettings), key: ","))
            menu.addItem(.separator())
            menu.addItem(makeItem("Quit Clipboard Manager", action: #selector(NSApplication.terminate(_:)), key: "q"))
            statusItem.menu = menu
            statusItem.button?.performClick(nil)
            statusItem.menu = nil
        } else {
            togglePanel()
        }
    }

    private func makeItem(_ title: String, action: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    // MARK: - Panel

    private func setupPanel() {
        let content = MainPanelView(viewModel: viewModel, onDismiss: { [weak self] in self?.hidePanel() })
        hostingController = NSHostingController(rootView: content)
        hostingController.view.frame = NSRect(origin: .zero, size: NSSize(width: 820, height: 560))

        panel = FloatingPanel(contentRect: NSRect(x: 0, y: 0, width: 820, height: 560))
        panel.contentViewController = hostingController
        panel.isReleasedWhenClosed = false
        centerPanel()
    }

    private func centerPanel() {
        guard let screen = NSScreen.main else { return }
        let sr = screen.visibleFrame
        let x = sr.midX - panel.frame.width  / 2
        let y = sr.midY - panel.frame.height / 2 + 60
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    // MARK: - Hotkey

    private func setupHotkey() {
        HotkeyService.shared.onTriggered = { [weak self] in
            DispatchQueue.main.async { self?.togglePanel() }
        }
        HotkeyService.shared.register()
    }

    // MARK: - Key event monitor

    private func setupKeyMonitor() {
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.panel.isVisible else { return event }
            switch Int(event.keyCode) {
            case 125: // ↓
                self.viewModel.selectNext()
                return nil
            case 126: // ↑
                self.viewModel.selectPrevious()
                return nil
            case 36:  // Return
                if let item = self.viewModel.selectedItem {
                    self.viewModel.pasteItem(item) { self.hidePanel() }
                }
                return nil
            case 53:  // Escape
                self.hidePanel()
                return nil
            default:
                return event
            }
        }
    }

    // MARK: - Show / Hide

    @objc func togglePanel() { panel.isVisible ? hidePanel() : showPanel() }

    @objc func showPanel() {
        centerPanel()
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func hidePanel() { panel.orderOut(nil) }

    // MARK: - Menu actions

    @objc func toggleMonitoring() {
        ClipboardMonitor.shared.toggle()
    }

    @objc func openSettings() {
        viewModel.showSettings = true
        showPanel()
    }

}

// MARK: - FloatingPanel

final class FloatingPanel: NSPanel {

    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isOpaque             = false
        backgroundColor      = .clear
        level                = .floating
        collectionBehavior   = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        isMovableByWindowBackground = true
        hasShadow            = true
        animationBehavior    = .utilityWindow
    }

    override var canBecomeKey:  Bool { true }
    override var canBecomeMain: Bool { false }
}
