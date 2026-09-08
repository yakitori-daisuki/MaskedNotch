import XCTest

final class VariantRefreshTests: XCTestCase {
    @MainActor func testStopAndRestartRejectOldCallbacks() async {
        let refresh = VariantRefresh()
        var staleCalls = 0
        refresh.start(interval: 0.02) { staleCalls += 1 }
        refresh.stop()
        let tick = expectation(description: "New timer fires")
        var calls = 0
        refresh.start(interval: 0.02) {
            calls += 1
            refresh.stop()
            tick.fulfill()
        }
        refresh.start(interval: 0.02) { XCTFail("Duplicate start replaced timer") }
        await fulfillment(of: [tick], timeout: 2)
        let quiet = expectation(description: "Stopped timer remains quiet")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { quiet.fulfill() }
        await fulfillment(of: [quiet], timeout: 1)
        XCTAssertEqual(staleCalls, 0)
        XCTAssertEqual(calls, 1)
    }
}
