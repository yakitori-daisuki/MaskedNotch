import AppKit
import XCTest

final class RefreshProbeTests: XCTestCase {
    @MainActor func testCompletionRemovesPeriodicUpdatesAndStartIsIdempotent() async {
        let finished = expectation(description: "Experiment completed")
        var phases: [RefreshProbe.Phase] = []
        var steps: [RefreshProbe.Phase] = []
        var reports: [String] = []
        let probe = RefreshProbe(phaseDurations: [0.05, 0.12, 0.12], interval: 0.02,
            step: { steps.append($0); return true },
            changed: { phase in
                if let phase { phases.append(phase) } else { finished.fulfill() }
            }, record: { reports.append($0) })
        probe.start()
        probe.start()
        await fulfillment(of: [finished], timeout: 2)
        XCTAssertEqual(phases, [.baseline, .redraw, .order])
        XCTAssertFalse(steps.contains(.baseline))
        XCTAssertTrue(steps.contains(.redraw))
        XCTAssertTrue(steps.contains(.order))
        XCTAssertEqual(reports.filter { $0.contains("summary") && $0.contains("completed=true") }.count, 3)
        let countAtEnd = steps.count
        let quiet = expectation(description: "No recurring work after completion")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { quiet.fulfill() }
        await fulfillment(of: [quiet], timeout: 1)
        XCTAssertEqual(steps.count, countAtEnd)
        probe.stop()
    }

    @MainActor func testStopCancelsQueuedTicksAndNextPhase() async {
        let stopped = expectation(description: "Stopped on first redraw")
        var phases: [RefreshProbe.Phase] = []
        var count = 0
        var probe: RefreshProbe?
        probe = RefreshProbe(phaseDurations: [0.05, 0.12, 0.12], interval: 0.02,
            step: { _ in count += 1; probe?.stop(); stopped.fulfill(); return false },
            changed: { if let phase = $0 { phases.append(phase) } }, record: { _ in })
        probe?.start()
        await fulfillment(of: [stopped], timeout: 2)
        let quiet = expectation(description: "Cancelled transition does not run")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { quiet.fulfill() }
        await fulfillment(of: [quiet], timeout: 1)
        XCTAssertEqual(count, 1)
        XCTAssertEqual(phases, [.baseline, .redraw])
        probe = nil
    }

    @MainActor func testInvalidOrUnboundedDurationsCannotStart() {
        for durations in [[1.0, 1.0, 101.0], [1.0, 1.0], [1.0, -1.0, 1.0], [1.0, .infinity, 1.0]] {
            let probe = RefreshProbe(phaseDurations: durations,
                step: { _ in XCTFail("Invalid experiment must not tick"); return false },
                changed: { _ in XCTFail("Invalid experiment must not start") }, record: { _ in })
            probe.start()
            probe.stop()
        }
    }
}
