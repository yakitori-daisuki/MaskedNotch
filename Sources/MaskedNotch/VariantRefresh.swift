import Foundation

/// The visible desktop panel owns this timer. Normal builds use the redraw strategy.
final class VariantRefresh {
    private var timer: DispatchSourceTimer?
    private var generation = 0

    func start(interval: TimeInterval = 0.5, step: @escaping () -> Void) {
        guard timer == nil, interval.isFinite, interval > 0 else { return }
        generation += 1
        let ticket = generation
        let source = DispatchSource.makeTimerSource(queue: .main)
        source.schedule(deadline: .now() + interval, repeating: interval, leeway: .milliseconds(20))
        source.setEventHandler { [weak self] in
            guard let self, self.timer != nil, self.generation == ticket else { return }
            step()
        }
        timer = source
        source.resume()
    }

    func stop() {
        generation += 1
        timer?.cancel()
        timer = nil
    }

    deinit { timer?.cancel() }
}
