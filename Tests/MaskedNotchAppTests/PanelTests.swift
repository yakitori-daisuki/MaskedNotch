import AppKit
import XCTest

final class PanelTests: XCTestCase {
    @MainActor func testQuartzDrawingCoversBlueBackingAtEachScaleAndAfterResize() throws {
        _ = NSApplication.shared
        let panel = BandPanel(frame: CGRect(x: 0, y: 0, width: 320, height: 38),
                              locked: false, rendering: .quartzFill)
        defer { panel.close() }
        let view = try XCTUnwrap(panel.contentView)
        XCTAssertFalse(view.wantsLayer, "Quartz path must not reuse the CALayer renderer")
        for size in [CGSize(width: 320, height: 38), CGSize(width: 427, height: 39)] {
            panel.setContentSize(size)
            for scale in [1, 2] {
                let width = Int(size.width) * scale
                let height = Int(size.height) * scale
                let space = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
                let context = try XCTUnwrap(CGContext(data: nil, width: width, height: height,
                    bitsPerComponent: 8, bytesPerRow: width * 4, space: space,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
                context.setFillColor(NSColor.blue.cgColor)
                context.fill(CGRect(x: 0, y: 0, width: width, height: height))
                context.scaleBy(x: CGFloat(scale), y: CGFloat(scale))
                NSGraphicsContext.saveGraphicsState()
                NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
                view.draw(view.bounds)
                NSGraphicsContext.restoreGraphicsState()
                let pixels = try XCTUnwrap(context.data).assumingMemoryBound(to: UInt8.self)
                let wrongPixels = (0..<(width * height)).filter {
                    let offset = $0 * 4
                    return pixels[offset] != 0 || pixels[offset + 1] != 0 ||
                        pixels[offset + 2] != 0 || pixels[offset + 3] != 255
                }.count
                XCTAssertEqual(wrongPixels, 0)
            }
        }
    }

    @MainActor func testWallpaperPlacementIsAboveDesktopSurfacesButBelowAppsAndMenus() {
        _ = NSApplication.shared
        let panel = BandPanel(frame: CGRect(x: 0, y: 0, width: 320, height: 38),
                              locked: false, desktopPlacement: .aboveWallpaper)
        defer { panel.close() }
        XCTAssertGreaterThan(panel.level.rawValue, Int(CGWindowLevelForKey(.desktopWindow)))
        XCTAssertGreaterThan(panel.level.rawValue, Int(CGWindowLevelForKey(.desktopIconWindow)))
        // Observed WindowServer top-strip surface: desktopIconWindow + 1.
        XCTAssertGreaterThan(panel.level.rawValue, Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
        XCTAssertLessThan(panel.level.rawValue, NSWindow.Level.normal.rawValue)
        XCTAssertLessThan(panel.level.rawValue, NSWindow.Level.mainMenu.rawValue)
        XCTAssertTrue(panel.ignoresMouseEvents)
        XCTAssertFalse(panel.isVisible)
    }

    @MainActor func testLockPanelKeepsItsLevelWithWallpaperPlacementRequested() {
        _ = NSApplication.shared
        let panel = BandPanel(frame: CGRect(x: 0, y: 0, width: 320, height: 38),
                              locked: true, desktopPlacement: .aboveWallpaper)
        defer { panel.close() }
        XCTAssertEqual(panel.level.rawValue, NSWindow.Level.statusBar.rawValue - 1)
        XCTAssertTrue(panel.canBecomeVisibleWithoutLogin)
        XCTAssertFalse(panel.collectionBehavior.contains(.canJoinAllSpaces))
        XCTAssertTrue(panel.collectionBehavior.contains(.fullScreenAuxiliary))
    }

    @MainActor func testRedrawSubmitsNewPixelsEvenWhenWindowIsNotVisible() throws {
        _ = NSApplication.shared
        let panel = BandPanel(frame: CGRect(x: 0, y: 0, width: 320, height: 38), locked: false)
        defer { panel.close() }
        XCTAssertFalse(panel.isVisible)
        panel.redrawBlackSurface()
        let first = try XCTUnwrap(panel.contentView?.layer?.contents) as! CGImage
        panel.redrawBlackSurface()
        let second = try XCTUnwrap(panel.contentView?.layer?.contents) as! CGImage
        XCTAssertFalse(first === second)
        let data = try XCTUnwrap(second.dataProvider?.data)
        let bytes = try XCTUnwrap(CFDataGetBytePtr(data))
        XCTAssertEqual(Array(UnsafeBufferPointer(start: bytes, count: 4)), [0, 0, 0, 255])
    }
    @MainActor func testBandCannotTakeInputOrFocus() {
        _ = NSApplication.shared
        for locked in [false, true] {
            let panel = BandPanel(frame: CGRect(x: 100, y: 100, width: 500, height: 38), locked: locked)
            defer { panel.close() }
            XCTAssertFalse(panel.canBecomeKey)
            XCTAssertFalse(panel.canBecomeMain)
            XCTAssertTrue(panel.ignoresMouseEvents)
            XCTAssertFalse(panel.acceptsMouseMovedEvents)
            XCTAssertFalse(panel.hasShadow)
            XCTAssertFalse(panel.isOpaque)
            XCTAssertEqual(panel.alphaValue, 1)
            XCTAssertNil(panel.contentView?.hitTest(.zero))
            XCTAssertEqual(panel.backgroundColor.alphaComponent, 0)
            XCTAssertEqual(panel.contentView?.layer?.backgroundColor?.alpha, 1)
            XCTAssertEqual(panel.contentView?.layer?.opacity, 1)
            XCTAssertTrue(panel.contentView?.isOpaque == true)
            XCTAssertEqual(panel.canBecomeVisibleWithoutLogin, locked)
        }
    }
    @MainActor func testDesktopPanelIsStationaryAndKeepsFiniteLevel() {
        _ = NSApplication.shared
        let panel = BandPanel(frame: CGRect(x: 0, y: 0, width: 500, height: 38), locked: false)
        defer { panel.close() }
        XCTAssertFalse(panel.collectionBehavior.contains(.transient))
        XCTAssertTrue(panel.collectionBehavior.contains(.stationary))
        XCTAssertFalse(panel.collectionBehavior.contains(.fullScreenAuxiliary))
        XCTAssertEqual(panel.level.rawValue, NSWindow.Level.statusBar.rawValue - 1)
        XCTAssertFalse(panel.isVisible)
    }

    /// Check the band's own pixels, independently of WindowServer/menu compositing.
    @MainActor func testBlackLayerCoversEntireResizedSurfaceAtEachScale() throws {
        _ = NSApplication.shared
        let panel = BandPanel(frame: CGRect(x: 0, y: 0, width: 320, height: 38), locked: false)
        defer { panel.close() }
        let view = try XCTUnwrap(panel.contentView)
        for size in [CGSize(width: 320, height: 38), CGSize(width: 427, height: 39)] {
            panel.setContentSize(size)
            view.layoutSubtreeIfNeeded()
            view.displayIfNeeded()
            let layer = try XCTUnwrap(view.layer)
            XCTAssertEqual(layer.bounds.size, size)
            XCTAssertTrue(layer.animationKeys()?.isEmpty ?? true)
            for scale in [1, 2] {
                let width = Int(size.width) * scale
                let height = Int(size.height) * scale
                let space = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
                let context = try XCTUnwrap(CGContext(data: nil, width: width, height: height,
                    bitsPerComponent: 8, bytesPerRow: width * 4, space: space,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
                context.setFillColor(NSColor.blue.cgColor)
                context.fill(CGRect(x: 0, y: 0, width: width, height: height))
                context.scaleBy(x: CGFloat(scale), y: CGFloat(scale))
                layer.render(in: context)
                let pixels = try XCTUnwrap(context.data).assumingMemoryBound(to: UInt8.self)
                let wrongPixels = (0..<(width * height)).filter { pixel in
                    let offset = pixel * 4
                    return pixels[offset] != 0 || pixels[offset + 1] != 0 ||
                        pixels[offset + 2] != 0 || pixels[offset + 3] != 255
                }.count
                XCTAssertEqual(wrongPixels, 0, "Black layer must cover blue test backing, including every edge")
            }
        }
    }
}
