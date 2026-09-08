// Read-only development diagnostic. No windows, screenshots, AX, settings writes,
// app launches, or process termination. Window metadata does not prove pixel color.
import AppKit
import Darwin

func preference(_ key: String, domain: String) -> Any {
    CFPreferencesCopyAppValue(key as CFString, domain as CFString) ?? NSNull()
}

func menuBarBackground() -> [String: Any] {
    // Private, read-only SPI used by the earlier local investigation. Keep it out
    // of the shipping app and report unavailable rather than guessing a default.
    let path = "/System/Library/PrivateFrameworks/SkyLight.framework/Versions/A/SkyLight"
    guard let handle = dlopen(path, RTLD_NOW) else {
        return ["value": NSNull(), "error": "SkyLight unavailable"]
    }
    defer { dlclose(handle) }
    guard let connectionSymbol = dlsym(handle, "SLSMainConnectionID"),
          let readSymbol = dlsym(handle, "SLSGetMenuBarUseBlurredAppearance") else {
        return ["value": NSNull(), "error": "Read-only SPI unavailable"]
    }
    let connection = unsafeBitCast(connectionSymbol, to: (@convention(c) () -> Int32).self)
    let read = unsafeBitCast(readSymbol, to: (@convention(c) (Int32) -> Bool).self)
    let cid = connection()
    guard cid != 0 else {
        return ["value": NSNull(), "error": "No WindowServer connection"]
    }
    return ["value": read(cid), "source": "SLSGetMenuBarUseBlurredAppearance"]
}

let applications = NSWorkspace.shared.runningApplications.filter {
    $0.bundleIdentifier?.hasPrefix("local.MaskedNotch") == true
}
let pids = Set(applications.map { $0.processIdentifier })
let allWindows = CGWindowListCopyWindowInfo(.optionAll, kCGNullWindowID) as? [[String: Any]]
let bandWindows = (allWindows ?? []).filter {
    guard let pid = $0[kCGWindowOwnerPID as String] as? Int32 else { return false }
    return pids.contains(pid)
}.map { row -> [String: Any] in
    // Deliberately omit window titles and other apps' content.
    var result: [String: Any] = [:]
    for key in [kCGWindowNumber, kCGWindowOwnerPID, kCGWindowBounds,
                kCGWindowLayer, kCGWindowAlpha, kCGWindowIsOnscreen] {
        result[key as String] = row[key as String] ?? NSNull()
    }
    return result
}
let appStates: [[String: Any]] = applications.map { app in
    let bundle = app.bundleURL.flatMap(Bundle.init(url:))
    let domain = app.bundleIdentifier ?? "local.MaskedNotch"
    return [
        "bundleIdentifier": domain,
        "bundlePath": app.bundleURL?.path ?? "unknown",
        "build": bundle?.object(forInfoDictionaryKey: "CFBundleVersion") ?? NSNull(),
        "desktopPlacement": bundle?.object(forInfoDictionaryKey: "MaskedNotchDesktopPlacement") ?? NSNull(),
        "layeredBands": bundle?.object(forInfoDictionaryKey: "MaskedNotchLayeredBands") ?? false,
        "pid": app.processIdentifier,
        "hidden": app.isHidden,
        "activationPolicy": app.activationPolicy.rawValue,
        "hideNotch": preference("hideNotch", domain: domain),
    ]
}
let displays: [[String: Any]] = NSScreen.screens.compactMap { screen in
    guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber,
          CGDisplayIsBuiltin(number.uint32Value) != 0 else { return nil }
    let id = number.uint32Value
    return [
        "id": id,
        "active": CGDisplayIsActive(id) != 0,
        "online": CGDisplayIsOnline(id) != 0,
        "mirrored": CGDisplayIsInMirrorSet(id) != 0,
        "bounds": CGDisplayBounds(id).dictionaryRepresentation,
        "safeTop": screen.safeAreaInsets.top,
        "scale": screen.backingScaleFactor,
    ]
}

let global = UserDefaults.standard
let report: [String: Any] = [
    "capturedAt": ISO8601DateFormatter().string(from: Date()),
    "operatingSystem": ProcessInfo.processInfo.operatingSystemVersionString,
    "menuBarBackground": menuBarBackground(),
    "reduceTransparency": NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency,
    "increaseContrast": NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast,
    "reduceMotion": NSWorkspace.shared.accessibilityDisplayShouldReduceMotion,
    "menuBarAutoHidePreference": global.object(forKey: "_HIHideMenuBar") ?? NSNull(),
    "interfaceStylePreference": global.object(forKey: "AppleInterfaceStyle") ?? NSNull(),
    // Raw value only: this is distinct from Show Menu Bar Background.
    "glassDiffusionPreference": global.object(forKey: "NSGlassDiffusionSetting") ?? NSNull(),
    "applications": appStates,
    "windowMetadataAvailable": allWindows != nil,
    "bandWindows": bandWindows,
    "builtInDisplays": displays,
    "limitation": "Settings and window metadata only; final visible pixel colors are not measured.",
]
do {
    let data = try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
    FileHandle.standardOutput.write(data)
    FileHandle.standardOutput.write(Data("\n".utf8))
} catch {
    FileHandle.standardError.write(Data("Unable to serialize diagnostic: \(error)\n".utf8))
    exit(1)
}
