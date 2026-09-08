import XCTest
#if canImport(MaskedNotchCore)
@testable import MaskedNotchCore
#endif

final class StateTests: XCTestCase {
    private func desktop() -> DisplayState {
        var state = DisplayState(enabled: true)
        state.locked = false
        state.ownConsole = true
        state.targetAvailable = true
        return state
    }
    func testStartupWaitsForSessionAndTarget() {
        XCTAssertEqual(DisplayState(enabled: true).mode, .hidden)
        var state = desktop(); state.targetAvailable = false
        XCTAssertEqual(state.mode, .hidden)
    }
    func testRepeatedLockUnlockUsesSharedPreference() {
        var state = desktop()
        for _ in 0..<100 {
            state.locked = true; XCTAssertEqual(state.mode, .locked)
            state.locked = false; XCTAssertEqual(state.mode, .desktop)
        }
        state.enabled = false
        for locked in [true, false] { state.locked = locked; XCTAssertEqual(state.mode, .hidden) }
    }
    func testWakeWhileLockedRestoresLockMode() {
        var state = desktop(); state.locked = true; state.sleeping = true
        XCTAssertEqual(state.mode, .hidden)
        state.sleeping = false
        XCTAssertEqual(state.mode, .locked)
    }
    func testFastUserSwitchAndUnknownSessionAreHidden() {
        var state = desktop(); state.locked = true; state.ownConsole = false
        XCTAssertEqual(state.mode, .hidden)
        state.ownConsole = true; state.locked = nil
        XCTAssertEqual(state.mode, .hidden)
    }
    func testLockBackendFailurePreservesDesktop() {
        var state = desktop(); state.lockUnavailable = true; state.locked = true
        XCTAssertEqual(state.mode, .hidden)
        state.locked = false
        XCTAssertEqual(state.mode, .desktop)
    }
    func testFullscreenSuppressionDoesNotSuppressLockedScreenSaver() {
        var state = desktop(); state.desktopSuppressed = true
        XCTAssertEqual(state.mode, .hidden)
        state.locked = true
        XCTAssertEqual(state.mode, .locked)
        state.locked = false; state.desktopSuppressed = false
        XCTAssertEqual(state.mode, .desktop)
    }
    func testDelayedRetryCannotResurrectAfterOffThenOn() {
        var state = desktop()
        let oldTicket = state.invalidate()
        state.enabled = false; state.invalidate()
        XCTAssertFalse(state.accepts(oldTicket))
        state.enabled = true; let newest = state.invalidate()
        XCTAssertFalse(state.accepts(oldTicket))
        XCTAssertTrue(state.accepts(newest))
    }
    func testRapidLockUnlockInvalidatesPreviousCallbacks() {
        var state = desktop(); state.locked = true
        let lockedTicket = state.invalidate()
        state.locked = false; let unlockedTicket = state.invalidate()
        XCTAssertFalse(state.accepts(lockedTicket))
        XCTAssertTrue(state.accepts(unlockedTicket))
        XCTAssertEqual(state.mode, .desktop)
    }
    func testNoDisplayAfterQueuedRetryStaysHidden() {
        var state = desktop(); let ticket = state.invalidate()
        state.targetAvailable = false
        XCTAssertTrue(state.accepts(ticket))
        XCTAssertEqual(state.mode, .hidden)
    }
    func testSleepTerminationAndOffRejectEvenCurrentTicket() {
        var state = desktop(); let ticket = state.invalidate()
        state.sleeping = true; XCTAssertFalse(state.accepts(ticket))
        state.sleeping = false; state.enabled = false; XCTAssertFalse(state.accepts(ticket))
        state.enabled = true; state.terminating = true
        XCTAssertFalse(state.accepts(ticket)); XCTAssertEqual(state.mode, .hidden)
    }
}
