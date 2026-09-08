import Foundation

/// Cancels delayed reappearance when the owning panel is withdrawn.
final class BlinkPulse {
    private var pending: DispatchWorkItem?
    private var generation = 0
    var isPending: Bool { pending != nil }

    func begin(delay: TimeInterval = 0.1, hide: () -> Void, show: @escaping () -> Void) {
        guard pending == nil else { return }
        generation += 1
        let ticket = generation
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.generation == ticket else { return }
            self.pending = nil
            show()
        }
        pending = work
        hide()
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    func cancel() {
        generation += 1
        pending?.cancel()
        pending = nil
    }
    deinit { pending?.cancel() }
}
