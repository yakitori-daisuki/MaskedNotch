import Foundation
import CoreGraphics

/// All rectangles and insets are AppKit points, never physical pixels.
struct DisplayGeometry: Equatable {
    let id: UInt32
    let builtIn: Bool
    let active: Bool
    let mirrored: Bool
    let frame: CGRect
    let safeTop: CGFloat
    let auxiliaryLeft: CGRect?
    let auxiliaryRight: CGRect?
    let scale: CGFloat

    var band: CGRect? {
        guard builtIn, active, !mirrored, scale.isFinite, scale > 0,
              frame.origin.x.isFinite, frame.origin.y.isFinite,
              frame.width.isFinite, frame.height.isFinite,
              frame.width > 0, frame.height > 0,
              safeTop.isFinite, safeTop > 0, safeTop < frame.height,
              let left = auxiliaryLeft, let right = auxiliaryRight,
              left.width > 0, right.width > 0,
              left.maxX < right.minX else { return nil }
        // Auxiliary areas validate the notch; safeTop defines its exclusion depth.
        // Round only the lower edge outward to the next physical pixel.
        let bottom = floor((frame.maxY - safeTop) * scale) / scale
        guard bottom >= frame.minY else { return nil }
        return CGRect(x: frame.minX, y: bottom, width: frame.width, height: frame.maxY - bottom)
    }
}
