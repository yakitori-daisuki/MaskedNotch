import XCTest
import CoreGraphics
#if canImport(MaskedNotchCore)
@testable import MaskedNotchCore
#endif

final class GeometryTests: XCTestCase {
    private func display(origin: CGPoint = .zero, scale: CGFloat = 2, safeTop: CGFloat = 38,
                         builtIn: Bool = true, active: Bool = true, mirrored: Bool = false,
                         hasNotch: Bool = true) -> DisplayGeometry {
        let frame = CGRect(origin: origin, size: CGSize(width: 1800, height: 1169))
        return DisplayGeometry(id: 1, builtIn: builtIn, active: active, mirrored: mirrored,
            frame: frame, safeTop: safeTop,
            auxiliaryLeft: hasNotch ? CGRect(x: frame.minX, y: frame.maxY - safeTop, width: 790, height: safeTop) : nil,
            auxiliaryRight: hasNotch ? CGRect(x: frame.minX + 1010, y: frame.maxY - safeTop, width: 790, height: safeTop) : nil,
            scale: scale)
    }

    func testNotchDepthNotMenuBarHeight() {
        let band = display().band
        XCTAssertEqual(band, CGRect(x: 0, y: 1131, width: 1800, height: 38))
    }
    func testNoTargetScreen() {
        let screens: [DisplayGeometry] = []
        XCTAssertNil(screens.compactMap(\.band).first)
    }
    func testExternalAndClosedLidAndMirrorDoNotRender() {
        XCTAssertNil(display(builtIn: false).band)
        XCTAssertNil(display(active: false).band)
        XCTAssertNil(display(mirrored: true).band)
    }
    func testNoNotchOrUnavailableGeometryDoNotGuessHeight() {
        XCTAssertNil(display(safeTop: 0).band)
        XCTAssertNil(display(hasNotch: false).band)
    }
    func testNonzeroAndNegativeOrigins() {
        for origin in [CGPoint(x: -1800, y: 420), CGPoint(x: 2560, y: -1169)] {
            XCTAssertEqual(display(origin: origin).band,
                           CGRect(x: origin.x, y: origin.y + 1131, width: 1800, height: 38))
        }
    }
    func testPointCoordinatesDoNotScaleWithPixelDensity() {
        XCTAssertEqual(display(scale: 1).band, display(scale: 2).band)
        XCTAssertEqual(display(scale: 3).band, display(scale: 2).band)
    }
    func testFractionalInsetRoundsOutByLessThanOnePixel() throws {
        for scale: CGFloat in [1, 1.5, 2, 3] {
            let screen = display(scale: scale, safeTop: 37.3)
            let band = try XCTUnwrap(screen.band)
            XCTAssertEqual(band.maxY, screen.frame.maxY)
            XCTAssertGreaterThanOrEqual(band.height, 37.3)
            XCTAssertLessThan(band.height - 37.3, 1 / scale)
            XCTAssertEqual(band.minY * scale, (band.minY * scale).rounded(), accuracy: 0.00001)
        }
    }
    func testInvalidGeometryFailsClosed() {
        for scale: CGFloat in [0, -1, .nan, .infinity] { XCTAssertNil(display(scale: scale).band) }
        for inset: CGFloat in [-1, 1169, 2000, .nan, .infinity] { XCTAssertNil(display(safeTop: inset).band) }
        XCTAssertNil(display(origin: CGPoint(x: CGFloat.nan, y: 0)).band)
    }
}
