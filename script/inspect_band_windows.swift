// Development-only metadata inspection. No screenshots, AX, inputs, or settings access.
import AppKit

let windows = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] ?? []
let minimumLevel = CommandLine.arguments.contains("--all-levels") ? Int.min : NSWindow.Level.mainMenu.rawValue
for screen in NSScreen.screens {
    guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber,
          CGDisplayIsBuiltin(number.uint32Value) != 0 else { continue }
    let display = CGDisplayBounds(number.uint32Value)
    let strip = CGRect(x: display.minX, y: display.minY, width: display.width,
                       height: max(screen.safeAreaInsets.top, NSStatusBar.system.thickness))
    print("display=\(number) frame=\(display) safeTop=\(screen.safeAreaInsets.top) scale=\(screen.backingScaleFactor)")
    // CoreGraphics lists windows from front to back. Retain only top-strip metadata.
    for row in windows {
        guard let bounds = row[kCGWindowBounds as String] as? NSDictionary,
              let frame = CGRect(dictionaryRepresentation: bounds), frame.intersects(strip),
              let level = row[kCGWindowLayer as String] as? Int, level >= minimumLevel else { continue }
        let owner = row[kCGWindowOwnerName as String] as? String ?? "unknown"
        let id = row[kCGWindowNumber as String] as? UInt32 ?? 0
        let alpha = row[kCGWindowAlpha as String] as? Double ?? -1
        print("owner=\(owner) id=\(id) level=\(level) alpha=\(alpha) frame=\(frame)")
    }
}
