import Foundation

final class Preferences {
    private let defaults: UserDefaults
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: ["hideNotch": true])
    }
    var enabled: Bool {
        get { defaults.bool(forKey: "hideNotch") }
        set { defaults.set(newValue, forKey: "hideNotch") }
    }
    var hasSeenIntroduction: Bool {
        get { defaults.bool(forKey: "hasSeenIntroduction") }
        set { defaults.set(newValue, forKey: "hasSeenIntroduction") }
    }
}
