// Read-only Space metadata. No screenshots, app activation, or Space switching.
import AppKit
import Darwin

guard let handle = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/Versions/A/SkyLight", RTLD_NOW),
      let connectionSymbol = dlsym(handle, "SLSMainConnectionID"),
      let copySymbol = dlsym(handle, "SLSCopyManagedDisplaySpaces") ?? dlsym(handle, "CGSCopyManagedDisplaySpaces") else {
    print("Space metadata unavailable")
    exit(1)
}
defer { dlclose(handle) }
let connection = unsafeBitCast(connectionSymbol, to: (@convention(c) () -> Int32).self)()
guard connection != 0 else { print("No WindowServer connection"); exit(1) }
let copySpaces = unsafeBitCast(copySymbol, to: (@convention(c) (Int32) -> Unmanaged<CFArray>?).self)
let waitDesktop = CommandLine.arguments.contains("--wait-for-desktop-1") ? 1 : 2
let waitForSecond = CommandLine.arguments.contains("--wait-for-desktop-2") || CommandLine.arguments.contains("--wait-for-desktop-1")
let deadline = ProcessInfo.processInfo.systemUptime + (waitForSecond ? 45 : 0)
repeat {
    guard let displays = copySpaces(connection)?.takeRetainedValue() as? [[String: Any]],
          displays.count == 1, let display = displays.first,
          let spaces = display["Spaces"] as? [[String: Any]],
          let current = display["Current Space"] as? [String: Any],
          let currentID = (current["ManagedSpaceID"] as? NSNumber)?.uint64Value else {
        print("Cannot identify one current display; no image should be requested")
        exit(1)
    }
    let desktopIDs = spaces.filter { ($0["type"] as? NSNumber)?.intValue == 0 }
        .compactMap { ($0["ManagedSpaceID"] as? NSNumber)?.uint64Value }
    let ordinal = desktopIDs.firstIndex(of: currentID).map { $0 + 1 }
    let isSecond = ordinal == 2
    if !waitForSecond || ordinal == waitDesktop || ProcessInfo.processInfo.systemUptime >= deadline {
        var report: [String: Any] = [
            "currentDesktopNumber": ordinal as Any? ?? NSNull(),
            "desktopCount": desktopIDs.count,
            "isDesktop2": isSecond,
            "currentSpaceID": currentID,
            "desktopSpaceIDs": desktopIDs,
            "source": "SLSCopyManagedDisplaySpaces (private read-only metadata)",
        ]
        if CommandLine.arguments.contains("--bands"),
           let symbol = dlsym(handle, "SLSCopySpacesForWindows") {
            let windowSpaces = unsafeBitCast(symbol, to: (@convention(c) (Int32, Int32, CFArray) -> Unmanaged<CFArray>?).self)
            let pids = Set(NSRunningApplication.runningApplications(withBundleIdentifier: "local.MaskedNotch.Desktop").map(\.processIdentifier))
            let windows = (CGWindowListCopyWindowInfo(.optionAll, kCGNullWindowID) as? [[String: Any]] ?? [])
                .filter { pids.contains(($0[kCGWindowOwnerPID as String] as? Int32) ?? -1) }
            report["bands"] = windows.compactMap { window -> [String: Any]? in
                guard let id = window[kCGWindowNumber as String] as? NSNumber else { return nil }
                return ["window": id, "level": window[kCGWindowLayer as String] ?? NSNull(),
                        "onscreen": window[kCGWindowIsOnscreen as String] ?? false,
                        "spaces": windowSpaces(connection, 7, [id] as CFArray)?.takeRetainedValue() as? [NSNumber] ?? []]
            }
        }
        let data = try JSONSerialization.data(withJSONObject: report, options: [.sortedKeys])
        FileHandle.standardOutput.write(data)
        FileHandle.standardOutput.write(Data("\n".utf8))
        exit(waitForSecond && ordinal != waitDesktop ? 2 : 0)
    }
    Thread.sleep(forTimeInterval: 0.5)
} while true
