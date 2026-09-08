import AppKit

enum StatusIcon {
    private static let on = makeImage(hidingNotch: true)
    private static let off = makeImage(hidingNotch: false)

    static func image(hidingNotch: Bool) -> NSImage { hidingNotch ? on : off }

    private static func makeImage(hidingNotch: Bool) -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            NSColor.black.setStroke()
            let outline = NSBezierPath(roundedRect: NSRect(x: 1.5, y: 3.5, width: 15, height: 11),
                                       xRadius: 2, yRadius: 2)
            outline.lineWidth = 1.5
            outline.stroke()
            NSColor.black.setFill()
            if hidingNotch {
                // Full-width band: the notch is hidden.
                NSRect(x: 2, y: 11, width: 14, height: 3).fill()
            } else {
                // Only the center notch: the rest of the screen's top edge is clear.
                NSBezierPath(roundedRect: NSRect(x: 6.5, y: 10.5, width: 5, height: 4),
                             xRadius: 1, yRadius: 1).fill()
            }
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = hidingNotch ? NSLocalizedString("Hide Notch: On", comment: "") : NSLocalizedString("Hide Notch: Off", comment: "")
        return image
    }
}
