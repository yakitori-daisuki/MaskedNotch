import AppKit
import XCTest

final class LayeredBandStackTests: XCTestCase {
    // Inject only ordering: lifecycle tests must not put test bands on the desktop.
    @MainActor func testRepeatedReplacementKeepsBasesAndBoundsLiveWindowCount() async {
        _ = NSApplication.shared
        var presented: [BandPanel] = []
        let stack = LayeredBandStack(frame: CGRect(x: 0, y: 0, width: 320, height: 38), displayID: 1) {
            panel, _ in presented.append(panel); return true
        }
        defer { stack.close() }
        let bases = Array(stack.panels.prefix(2))
        let originalMenu = stack.panels.last!
        stack.refresh()
        stack.refresh(replaceMenu: true)
        XCTAssertEqual(stack.panels.count, 4)
        XCTAssertTrue(stack.panels.contains { $0 === originalMenu })
        XCTAssertEqual(presented.last?.rendering, .quartzFill)
        for _ in 0..<50 { stack.refresh(replaceMenu: true) }
        XCTAssertEqual(stack.panels.count, 4, "Replacement overlap must be bounded")
        let retired = expectation(description: "Old band retired after overlap")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { retired.fulfill() }
        await fulfillment(of: [retired], timeout: 2)
        XCTAssertEqual(stack.panels.count, 3)
        XCTAssertFalse(stack.panels.contains { $0 === originalMenu })
        for base in bases { XCTAssertTrue(stack.panels.contains { $0 === base }) }
        for band in stack.panels {
            XCTAssertTrue(band.ignoresMouseEvents)
            XCTAssertFalse(band.canBecomeKey)
            XCTAssertLessThanOrEqual(band.level.rawValue, NSWindow.Level.mainMenu.rawValue)
            XCTAssertFalse(band.canBecomeVisibleWithoutLogin)
        }
    }

    @MainActor func testCloseDuringOverlapPreventsAnyLaterReappearance() async {
        _ = NSApplication.shared
        var presentations = 0
        let stack = LayeredBandStack(frame: CGRect(x: 0, y: 0, width: 320, height: 38), displayID: 1) {
            _, _ in presentations += 1; return true
        }
        stack.refresh()
        stack.refresh(replaceMenu: true)
        XCTAssertEqual(stack.panels.count, 4)
        stack.close()
        let before = presentations
        stack.refresh(replaceMenu: true)
        let quiet = expectation(description: "Retirement callback cannot revive closed stack")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { quiet.fulfill() }
        await fulfillment(of: [quiet], timeout: 2)
        stack.refresh()
        XCTAssertTrue(stack.panels.isEmpty)
        XCTAssertEqual(presentations, before)
        stack.close()
    }

    @MainActor func testFailedReplacementPreservesPreviousBand() {
        _ = NSApplication.shared
        var acceptedMenu: BandPanel?
        var rejectNewMenu = false
        let stack = LayeredBandStack(frame: CGRect(x: 0, y: 0, width: 320, height: 38), displayID: 1) {
            panel, _ in
            if panel.rendering != .quartzFill { return true }
            if rejectNewMenu && panel !== acceptedMenu { return false }
            acceptedMenu = panel
            return true
        }
        defer { stack.close() }
        stack.refresh()
        let previous = acceptedMenu
        rejectNewMenu = true
        stack.refresh(replaceMenu: true)
        XCTAssertEqual(stack.panels.count, 3)
        XCTAssertTrue(stack.panels.last === previous)
        rejectNewMenu = false
        stack.refresh(replaceMenu: true)
        XCTAssertEqual(stack.panels.count, 4)
        XCTAssertFalse(acceptedMenu === previous)
    }
}
