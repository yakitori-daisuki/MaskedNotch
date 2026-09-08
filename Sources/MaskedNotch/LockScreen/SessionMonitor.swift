import AppKit

struct SessionSnapshot {
    let ownConsole: Bool
    let locked: Bool?
}

/// Private notification names and the undocumented lock dictionary key live here only.
/// Public CGSession keys check UID/console ownership, never authentication data.
final class SessionMonitor {
    private var observers: [NSObjectProtocol] = []
    private var lastLockNotification: (locked: Bool, time: TimeInterval)?
    var changed: (() -> Void)?

    func start() {
        guard observers.isEmpty else { return }
        for (name, locked) in [("com.apple.screenIsLocked", true), ("com.apple.screenIsUnlocked", false)] {
            observers.append(DistributedNotificationCenter.default().addObserver(
                forName: Notification.Name(name), object: nil, queue: .main
            ) { [weak self] _ in
                self?.lastLockNotification = (locked, ProcessInfo.processInfo.systemUptime)
                self?.changed?()
            })
        }
    }

    func snapshot() -> SessionSnapshot {
        guard let dictionary = CGSessionCopyCurrentDictionary() as? [String: Any],
              let uid = dictionary[kCGSessionUserIDKey as String] as? NSNumber,
              let onConsole = dictionary[kCGSessionOnConsoleKey as String] as? Bool else {
            return SessionSnapshot(ownConsole: false, locked: nil)
        }
        let ownConsole = uid.uint32Value == getuid() && onConsole
        if !ownConsole { lastLockNotification = nil }
        // Notification beats a potentially stale dictionary during a transition.
        // On current macOS the private key is absent when unlocked. Require a complete
        // logged-in console record before using that convention; malformed values stay unknown.
        let loginDone = dictionary[kCGSessionLoginDoneKey as String] as? Bool == true
        let dictionaryLock: Bool? = dictionary["CGSSessionScreenIsLocked"] == nil
            ? (loginDone && ownConsole ? false : nil)
            : dictionary["CGSSessionScreenIsLocked"] as? Bool
        let recentNotification = lastLockNotification.flatMap {
            ProcessInfo.processInfo.systemUptime - $0.time < 2 ? $0.locked : nil
        }
        let locked = recentNotification ?? dictionaryLock
        return SessionSnapshot(ownConsole: ownConsole, locked: locked)
    }

    func stop() {
        for observer in observers { DistributedNotificationCenter.default().removeObserver(observer) }
        observers.removeAll()
        changed = nil
    }
    deinit { stop() }
}
