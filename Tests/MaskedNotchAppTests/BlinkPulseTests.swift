import XCTest

final class BlinkPulseTests: XCTestCase {
    @MainActor func testCancellationPreventsReappearance() async {
        let pulse = BlinkPulse()
        var hides = 0
        var shows = 0
        pulse.begin(delay: 0.03, hide: { hides += 1 }, show: { shows += 1 })
        pulse.begin(delay: 0.03, hide: { hides += 1 }, show: { shows += 1 })
        pulse.cancel()
        let waited = expectation(description: "Old show cannot run")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { waited.fulfill() }
        await fulfillment(of: [waited], timeout: 1)
        XCTAssertEqual(hides, 1)
        XCTAssertEqual(shows, 0)
        XCTAssertFalse(pulse.isPending)
    }

    @MainActor func testRestartShowsOnlyLatestPulse() async {
        let pulse = BlinkPulse()
        pulse.begin(delay: 0.02, hide: {}, show: { XCTFail("Cancelled pulse") })
        pulse.cancel()
        let shown = expectation(description: "New pulse shows")
        pulse.begin(delay: 0.03, hide: {}, show: { shown.fulfill() })
        await fulfillment(of: [shown], timeout: 1)
        XCTAssertFalse(pulse.isPending)
    }
}
