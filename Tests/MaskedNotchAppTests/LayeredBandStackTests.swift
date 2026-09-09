import AppKit
import XCTest

final class LayeredBandStackTests: XCTestCase {
    @MainActor func testActiveDesktopExperimentAppliesOnlyToMenuBandAndItsReplacement() {
        _ = NSApplication.shared
        let stack = LayeredBandStack(frame: CGRect(x: 0, y: 0, width: 320, height: 38), displayID: 1,
                                     menuScope: .activeDesktop) { _, _ in true }
        defer { stack.close() }
        stack.refresh(replaceMenu: true)
        XCTAssertEqual(stack.panels.count, 4)
        for panel in stack.panels {
            let isMenu = panel.rendering == .quartzFill
            XCTAssertEqual(panel.collectionBehavior.contains(.moveToActiveSpace), isMenu)
            XCTAssertEqual(panel.collectionBehavior.contains(.canJoinAllSpaces), !isMenu)
        }
    }

    @MainActor func testSpaceChangeRenewsEverySurfaceWithBoundedOverlap() async {
        _ = NSApplication.shared
        let stack = LayeredBandStack(frame: CGRect(x: 0, y: 0, width: 320, height: 38), displayID: 1) { _, _ in true }
        defer { stack.close() }
        let original = stack.panels
        stack.requestSpaceRefresh()
        for index in 0..<3 {
            stack.refresh()
            XCTAssertEqual(stack.panels.count, 4)
            for _ in 0..<20 { stack.refresh(replaceMenu: true) }
            XCTAssertEqual(stack.panels.count, 4)
            let retired = expectation(description: "Space replacement \(index) retired")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { retired.fulfill() }
            await fulfillment(of: [retired], timeout: 2)
            XCTAssertEqual(stack.panels.count, 3)
        }
        for old in original { XCTAssertFalse(stack.panels.contains { $0 === old }) }
        XCTAssertEqual(Set(stack.panels.map(\.rendering)), Set([.windowFill, .layerPixels, .quartzFill]))
        for band in stack.panels { XCTAssertTrue(band.collectionBehavior.contains(.canJoinAllSpaces)) }
    }

    @MainActor func testFailedSpaceReplacementRetriesAndCloseCancelsPendingWork() {
        _ = NSApplication.shared
        var reject = false
        var presentations = 0
        let stack = LayeredBandStack(frame: CGRect(x: 0, y: 0, width: 320, height: 38), displayID: 1) { _, _ in
            presentations += 1
            return !reject
        }
        let old = stack.panels[0]
        stack.requestSpaceRefresh()
        reject = true
        stack.refresh()
        XCTAssertTrue(stack.panels[0] === old)
        XCTAssertEqual(stack.panels.count, 3)
        reject = false
        stack.refresh()
        XCTAssertFalse(stack.panels[0] === old)
        XCTAssertEqual(stack.panels.count, 4)
        for _ in 0..<30 { stack.requestSpaceRefresh(); stack.refresh() }
        XCTAssertEqual(stack.panels.count, 4)
        stack.close()
        let before = presentations
        stack.requestSpaceRefresh()
        stack.refresh()
        XCTAssertTrue(stack.panels.isEmpty)
        XCTAssertEqual(presentations, before)
    }

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
