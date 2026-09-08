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
let waitForSecond = CommandLine.arguments.contains("--wait-for-desktop-2")
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
    if !waitForSecond || isSecond || ProcessInfo.processInfo.systemUptime >= deadline {
        let report: [String: Any] = [
            "currentDesktopNumber": ordinal as Any? ?? NSNull(),
            "desktopCount": desktopIDs.count,
            "isDesktop2": isSecond,
            "currentSpaceID": currentID,
            "source": "SLSCopyManagedDisplaySpaces (private read-only metadata)",
        ]
        let data = try JSONSerialization.data(withJSONObject: report, options: [.sortedKeys])
        FileHandle.standardOutput.write(data)
        FileHandle.standardOutput.write(Data("\n".utf8))
        exit(waitForSecond && !isSecond ? 2 : 0)
    }
    Thread.sleep(forTimeInterval: 0.5)
} while true
