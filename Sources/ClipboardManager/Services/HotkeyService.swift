import AppKit
import Carbon.HIToolbox

// MARK: - HotkeyService

final class HotkeyService: @unchecked Sendable {
    static let shared = HotkeyService()

    var onTriggered: (() -> Void)?

    private var monitor: Any?

    private init() {}

    func register() {
        monitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.modifierFlags.intersection([.command, .shift, .option, .control]) == [.command, .shift],
                  event.keyCode == UInt16(kVK_ANSI_V) else { return }
            DispatchQueue.main.async { self?.onTriggered?() }
        }
    }

    func unregister() {
        if let m = monitor { NSEvent.removeMonitor(m) }
        monitor = nil
    }

    deinit { unregister() }
}
