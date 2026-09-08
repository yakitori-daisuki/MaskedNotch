import Foundation
import OSLog

/// Opt-in local integration evidence. Never records window contents, input or session identifiers.
enum Diagnostics {
    static var enabled = false
    private static let logger = Logger(subsystem: "local.MaskedNotch", category: "Probe")
    private static let lifecycle = Logger(subsystem: "local.MaskedNotch", category: "Lifecycle")
    /// Low-volume state/action boundaries are retained in normal launches too.
    static func event(_ event: String) {
        lifecycle.notice("\(event, privacy: .public)")
    }
    static func record(_ event: String) {
        guard enabled else { return }
        logger.notice("\(event, privacy: .public)")
    }
}
