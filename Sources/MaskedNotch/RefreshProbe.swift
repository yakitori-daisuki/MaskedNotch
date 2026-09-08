import AppKit

/// Explicit, bounded development experiment; never started by a normal launch.
final class RefreshProbe {
    enum Phase: String, CaseIterable {
        case baseline, redraw, order
        var label: String {
            switch self {
            case .baseline: NSLocalizedString("Baseline (for comparison)", comment: "")
            case .redraw: NSLocalizedString("A: Redraw every 0.5 seconds", comment: "")
            case .order: NSLocalizedString("B: Reorder every 0.5 seconds", comment: "")
            }
        }
    }

    private let step: (Phase) -> Bool
    private let changed: (Phase?) -> Void
    private let record: (String) -> Void
    private let phaseDurations: [TimeInterval]
    private let interval: TimeInterval
    private var timer: DispatchSourceTimer?
    private var transition: DispatchWorkItem?
    private var generation = 0
    private var running = false
    private var phaseIndex: Int?
    private var startedAt = 0.0
    private var deadline = 0.0
    private var startingCPU: Double?
    private var ticks = 0
    private var applied = 0

    init(phaseDurations: [TimeInterval] = [20, 40, 40], interval: TimeInterval = 0.5,
         step: @escaping (Phase) -> Bool, changed: @escaping (Phase?) -> Void,
         record: @escaping (String) -> Void = Diagnostics.record) {
        self.phaseDurations = phaseDurations
        self.interval = interval
        self.step = step
        self.changed = changed
        self.record = record
    }

    func start() {
        guard !running, phaseDurations.count == Phase.allCases.count,
              phaseDurations.allSatisfy({ $0.isFinite && $0 > 0 }),
              phaseDurations.reduce(0, +) <= 100,
              interval.isFinite, interval > 0 else { return }
        running = true
        generation += 1
        begin(0, ticket: generation)
    }

    private func begin(_ index: Int, ticket: Int) {
        guard running, ticket == generation else { return }
        phaseIndex = index
        startedAt = ProcessInfo.processInfo.systemUptime
        deadline = startedAt + phaseDurations[index]
        startingCPU = Self.cpuSeconds()
        ticks = 0
        applied = 0
        let phase = Phase.allCases[index]
        changed(phase)
        record("refresh-probe start phase=\(phase.rawValue) seconds=\(phaseDurations[index]) interval=\(interval)")
        if phase != .baseline {
            let source = DispatchSource.makeTimerSource(queue: .main)
            source.schedule(deadline: .now() + interval, repeating: interval, leeway: .milliseconds(20))
            source.setEventHandler { [weak self] in
                guard let self, self.running, self.generation == ticket,
                      self.phaseIndex == index,
                      ProcessInfo.processInfo.systemUptime < self.deadline else { return }
                self.ticks += 1
                if self.step(phase) { self.applied += 1 }
            }
            timer = source
            source.resume()
        }
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.running, self.generation == ticket else { return }
            self.finishPhase(completed: true)
            if index + 1 < Phase.allCases.count {
                self.begin(index + 1, ticket: ticket)
            } else {
                self.stop()
                self.record("refresh-probe finished; periodic updates removed")
            }
        }
        transition = work
        DispatchQueue.main.asyncAfter(deadline: .now() + phaseDurations[index], execute: work)
    }

    private func finishPhase(completed: Bool) {
        timer?.cancel()
        timer = nil
        guard let index = phaseIndex else { return }
        let elapsed = ProcessInfo.processInfo.systemUptime - startedAt
        let cpu: String
        if let start = startingCPU, let end = Self.cpuSeconds(), elapsed > 0 {
            cpu = String(format: "cpuSeconds=%.6f cpuPercentOneCore=%.4f", end - start, 100 * (end - start) / elapsed)
        } else { cpu = "cpuUnavailable=true" }
        record("refresh-probe summary phase=\(Phase.allCases[index].rawValue) completed=\(completed) elapsed=\(elapsed) \(cpu) ticks=\(ticks) applied=\(applied) skipped=\(ticks - applied)")
        phaseIndex = nil
    }

    func stop() {
        guard running else { return }
        running = false
        generation += 1
        transition?.cancel()
        transition = nil
        finishPhase(completed: false)
        changed(nil)
    }

    private static func cpuSeconds() -> Double? {
        var usage = rusage()
        guard getrusage(RUSAGE_SELF, &usage) == 0 else { return nil }
        return Double(usage.ru_utime.tv_sec + usage.ru_stime.tv_sec) +
            Double(usage.ru_utime.tv_usec + usage.ru_stime.tv_usec) / 1_000_000
    }
}
