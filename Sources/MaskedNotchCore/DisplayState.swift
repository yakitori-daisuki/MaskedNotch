import Foundation

enum DisplayMode: Equatable { case hidden, desktop, locked }

struct DisplayState {
    var enabled: Bool
    var locked: Bool? = nil
    var ownConsole = false
    var sleeping = false
    var terminating = false
    var targetAvailable = false
    var desktopSuppressed = false
    var lockUnavailable = false
    private(set) var generation: UInt64 = 0

    var mode: DisplayMode {
        guard enabled, ownConsole, !sleeping, !terminating, targetAvailable,
              let locked else { return .hidden }
        if locked { return lockUnavailable ? .hidden : .locked }
        return desktopSuppressed ? .hidden : .desktop
    }

    @discardableResult mutating func invalidate() -> UInt64 {
        generation &+= 1
        return generation
    }

    func accepts(_ ticket: UInt64) -> Bool {
        // A retry may re-read console ownership; mode still gates every rendering action.
        ticket == generation && enabled && !terminating && !sleeping
    }
}
