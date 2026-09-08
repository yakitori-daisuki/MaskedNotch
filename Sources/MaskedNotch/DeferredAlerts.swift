import AppKit

/// Standard alerts only while the owning console is known to be unlocked.
/// A lock/session/sleep transition aborts the modal and requeues its message.
final class DeferredAlerts {
    private weak var overlay: OverlayController?
    private var pending: [String] = []
    private var delivered: Set<String> = []
    private var active: NSAlert?
    private var scheduled = false
    private var interrupted = false
    private var stopped = false
    var acknowledged: ((String) -> Void)?

    init(overlay: OverlayController) { self.overlay = overlay }

    func enqueue(_ message: String) {
        guard !stopped, !delivered.contains(message), !pending.contains(message) else { return }
        pending.append(message)
        presentIfPossible()
    }

    func presentIfPossible() {
        guard !stopped, !scheduled, active == nil, !pending.isEmpty,
              overlay?.canPresentAlert == true else { return }
        scheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.scheduled = false
            guard !self.stopped, self.active == nil, let message = self.pending.first,
                  self.overlay?.canPresentAlert == true else { return }
            let alert = NSAlert()
            alert.messageText = "Masked Notch"
            alert.informativeText = message
            alert.addButton(withTitle: "OK")
            self.active = alert
            self.interrupted = false
            let response = alert.runModal()
            self.active = nil
            if !self.interrupted, response == .alertFirstButtonReturn {
                self.pending.removeAll { $0 == message }
                self.delivered.insert(message)
                self.acknowledged?(message)
            }
            self.presentIfPossible()
        }
    }

    func suspend() {
        guard let active else { return }
        interrupted = true
        if NSApp.modalWindow === active.window { NSApp.abortModal() }
        active.window.orderOut(nil)
    }

    func stop() { stopped = true; suspend(); pending.removeAll() }
}
