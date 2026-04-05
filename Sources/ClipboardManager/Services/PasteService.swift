import AppKit
import Carbon.HIToolbox

// MARK: - PasteService
// Synthesises Cmd+V to the previously-active application.
// Requires Accessibility permission (prompts on first use).

final class PasteService: @unchecked Sendable {
    static let shared = PasteService()
    private init() {}

    /// Copy item to pasteboard then send Cmd+V to the frontmost app.
    /// Call after the clipboard panel has hidden so the target app is front.
    func paste() {
        let opts = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        guard AXIsProcessTrusted() || AXIsProcessTrustedWithOptions(opts) else { return }

        guard let src = CGEventSource(stateID: .hidSystemState) else { return }
        let vKey = CGKeyCode(kVK_ANSI_V)

        let down = CGEvent(keyboardEventSource: src, virtualKey: vKey, keyDown: true)
        let up   = CGEvent(keyboardEventSource: src, virtualKey: vKey, keyDown: false)
        down?.flags = .maskCommand
        up?.flags   = .maskCommand
        down?.post(tap: .cgAnnotatedSessionEventTap)
        up?.post(tap: .cgAnnotatedSessionEventTap)
    }

    var hasAccessibilityPermission: Bool {
        AXIsProcessTrusted()
    }

    func requestAccessibilityPermission() {
        let opts = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        AXIsProcessTrustedWithOptions(opts)
    }
}
