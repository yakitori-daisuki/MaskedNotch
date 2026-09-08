import AppKit
import QuartzCore

enum DesktopBandPlacement: String {
    case underMenu
    case aboveWallpaper
    case wallpaperSurface

    static var configured: Self {
        (Bundle.main.object(forInfoDictionaryKey: "MaskedNotchDesktopPlacement") as? String)
            .flatMap(Self.init(rawValue:)) ?? .underMenu
    }

    var level: NSWindow.Level {
        switch self {
        case .underMenu:
            return NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue - 1)
        case .wallpaperSurface:
            return NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)) + 1)
        case .aboveWallpaper:
            // The desktop also contains Finder and a WindowServer top-strip
            // surface above the wallpaper level. Stay above that desktop stack,
            // but below every normal app window and the system menu.
            return NSWindow.Level(rawValue: NSWindow.Level.normal.rawValue - 1)
        }
    }
}

enum BandRendering: String {
    case layerPixels
    case quartzFill
    case windowFill
}

final class BandPanel: NSPanel {
    private let desktopPlacement: DesktopBandPlacement
    let rendering: BandRendering

    init(frame: CGRect, locked: Bool, desktopPlacement: DesktopBandPlacement = .underMenu,
         rendering: BandRendering = .layerPixels) {
        // The desktop experiment must not lower the panel inside the lock Space.
        self.desktopPlacement = locked ? .underMenu : desktopPlacement
        self.rendering = rendering
        super.init(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        title = "Masked Notch Band"
        isReleasedWhenClosed = false
        // The layered experiment deliberately uses separate rendering paths.
        // Existing builds and the lock panel keep their CALayer implementation.
        isOpaque = rendering != .layerPixels
        backgroundColor = rendering == .layerPixels ? .clear : NSColor(srgbRed: 0, green: 0, blue: 0, alpha: 1)
        colorSpace = .sRGB
        alphaValue = 1
        hasShadow = false
        ignoresMouseEvents = true
        acceptsMouseMovedEvents = false
        isMovable = false
        hidesOnDeactivate = false
        animationBehavior = .none
        isExcludedFromWindowsMenu = true
        canBecomeVisibleWithoutLogin = locked
        // The lock Space, not an extreme window level, controls lock visibility.
        level = self.desktopPlacement.level
        collectionBehavior = locked
            ? [.stationary, .ignoresCycle, .fullScreenAuxiliary]
            : [.stationary, .ignoresCycle, .canJoinAllSpaces, .fullScreenNone, .fullScreenDisallowsTiling]
        let contentFrame = CGRect(origin: .zero, size: frame.size)
        switch rendering {
        case .layerPixels: contentView = BlackView(frame: contentFrame)
        case .quartzFill: contentView = QuartzBlackView(frame: contentFrame)
        case .windowFill: contentView = EmptyBandView(frame: contentFrame)
        }
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
    override func isAccessibilityElement() -> Bool { false }

    /// Remain a physical-screen strip instead of joining the desktop thumbnail animation.
    /// Re-establish the order after Spaces/activation changes, always below OS menu glyphs.
    func restoreDesktopOrder(displayID: CGDirectDisplayID, redraw: Bool = true) {
        if desktopPlacement != .underMenu {
            // A cross-level relative order can move this window into the menu's
            // level. Stay at the desktop level for both launch and all retries.
            level = desktopPlacement.level
            orderFrontRegardless()
        } else if let menuID = SystemMenuBarWindow.find(on: displayID) {
            order(.below, relativeTo: Int(menuID))
        } else {
            // Do not jump above the system menu when its window is temporarily unavailable.
            orderBack(nil)
        }
        if redraw { redrawBlackSurface() }
    }

    /// Does not order in or create a window. Used separately by the timed experiment.
    func redrawBlackSurface() {
        // AppKit may skip displayIfNeeded for an occluded window. Submit fresh
        // opaque pixels directly instead of treating a display request as a redraw.
        switch rendering {
        case .layerPixels: (contentView as? BlackView)?.refreshSurface()
        case .quartzFill: contentView?.display()
        case .windowFill: display()
        }
        CATransaction.flush()
    }


}

private class EmptyBandView: NSView {
    override var acceptsFirstResponder: Bool { false }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
    override func isAccessibilityElement() -> Bool { false }
}

private final class QuartzBlackView: EmptyBandView {
    override var isOpaque: Bool { true }
    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.setBlendMode(.copy)
        context.setFillColor(NSColor(srgbRed: 0, green: 0, blue: 0, alpha: 1).cgColor)
        context.fill(bounds)
        Diagnostics.record("quartz-black drawn")
    }
}

private enum SystemMenuBarWindow {
    static func find(on displayID: CGDirectDisplayID) -> CGWindowID? {
        guard let windows = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] else { return nil }
        return find(on: displayID, windows: windows)
    }

    static func find(on displayID: CGDirectDisplayID, windows: [[String: Any]]) -> CGWindowID? {
        let screen = CGDisplayBounds(displayID)
        // Metadata only. No window images, menu contents, accessibility, or permissions.
        for window in windows {
            guard let owner = window[kCGWindowOwnerName as String] as? String,
                  owner == "Window Server" || owner == "WindowServer",
                  let layer = window[kCGWindowLayer as String] as? Int,
                  layer == NSWindow.Level.mainMenu.rawValue,
                  let bounds = window[kCGWindowBounds as String] as? NSDictionary,
                  let frame = CGRect(dictionaryRepresentation: bounds),
                  abs(frame.minX - screen.minX) <= 1,
                  abs(frame.minY - screen.minY) <= 1,
                  abs(frame.width - screen.width) <= 1,
                  frame.height > 0, frame.height < screen.height / 4,
                  let id = window[kCGWindowNumber as String] as? UInt32 else { continue }
            return id
        }
        return nil
    }
}

private final class BlackView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        autoresizingMask = [.width, .height]
        wantsLayer = true
        needsDisplay = true
    }

    required init?(coder: NSCoder) { nil }

    override var isOpaque: Bool { true }
    override var wantsUpdateLayer: Bool { true }
    override var acceptsFirstResponder: Bool { false }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
    override func isAccessibilityElement() -> Bool { false }
    override func makeBackingLayer() -> CALayer {
        let backing = CALayer()
        backing.isOpaque = true
        backing.backgroundColor = Self.black
        backing.opacity = 1
        backing.cornerRadius = 0
        // A Space/appearance transition must not animate our color or alpha.
        backing.actions = ["backgroundColor": NSNull(), "opacity": NSNull(),
                           "bounds": NSNull(), "position": NSNull(), "contents": NSNull()]
        return backing
    }

    override func updateLayer() {
        Diagnostics.record("black-layer updateLayer")
        refreshSurface()
    }

    func refreshSurface() {
        guard let layer,
              let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(data: nil, width: 1, height: 1,
                                      bitsPerComponent: 8, bytesPerRow: 4,
                                      space: colorSpace,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return }
        context.setFillColor(Self.black)
        context.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
        guard let pixels = context.makeImage() else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.backgroundColor = Self.black
        layer.opacity = 1
        layer.contents = pixels
        CATransaction.commit()
        Diagnostics.record("black-surface submitted pixels=1x1 alpha=1")
    }

    private static var black: CGColor {
        NSColor(srgbRed: 0, green: 0, blue: 0, alpha: 1).cgColor
    }
}
