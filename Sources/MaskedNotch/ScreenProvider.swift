import AppKit

enum ScreenProvider {
    static func target() -> (DisplayGeometry, CGRect)? {
        for screen in NSScreen.screens {
            guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { continue }
            let id = number.uint32Value
            let geometry = DisplayGeometry(
                id: id, builtIn: CGDisplayIsBuiltin(id) != 0,
                active: CGDisplayIsActive(id) != 0 && CGDisplayIsOnline(id) != 0,
                mirrored: CGDisplayIsInMirrorSet(id) != 0,
                frame: screen.frame, safeTop: screen.safeAreaInsets.top,
                auxiliaryLeft: screen.auxiliaryTopLeftArea,
                auxiliaryRight: screen.auxiliaryTopRightArea,
                scale: screen.backingScaleFactor)
            if let frame = geometry.band { return (geometry, frame) }
        }
        return nil
    }
}
