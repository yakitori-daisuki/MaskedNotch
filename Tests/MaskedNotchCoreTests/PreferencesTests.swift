import XCTest
#if canImport(MaskedNotchCore)
@testable import MaskedNotchCore
#endif

final class PreferencesTests: XCTestCase {
    func testDefaultOnAndPersistedOffAcrossInstances() throws {
        let suite = "local.MaskedNotch.tests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = Preferences(defaults: defaults)
        XCTAssertTrue(preferences.enabled)
        preferences.enabled = false
        let relaunched = Preferences(defaults: defaults)
        XCTAssertFalse(relaunched.enabled)
        var state = DisplayState(enabled: relaunched.enabled)
        state.ownConsole = true; state.targetAvailable = true
        for locked in [false, true] {
            state.locked = locked
            XCTAssertEqual(state.mode, .hidden)
        }
        // Login startup has no stored desired-state key and no automatic registration path.
        XCTAssertNil(defaults.object(forKey: "launchAtLogin"))
    }
    func testIntroductionAcknowledgementPersistsSeparately() throws {
        let suite = "local.MaskedNotch.tests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = Preferences(defaults: defaults)
        XCTAssertFalse(preferences.hasSeenIntroduction)
        preferences.hasSeenIntroduction = true
        XCTAssertTrue(Preferences(defaults: defaults).hasSeenIntroduction)
        XCTAssertTrue(preferences.enabled)
    }
}
