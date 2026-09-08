import AppKit
import ServiceManagement

final class StatusMenu: NSObject, NSMenuDelegate {
    private let statusItem: NSStatusItem
    private let menu = NSMenu()
    private let hideItem = NSMenuItem(title: NSLocalizedString("Hide Notch", comment: ""), action: #selector(toggleHidden), keyEquivalent: "")
    private let loginItem = NSMenuItem(title: NSLocalizedString("Launch at Login", comment: ""), action: #selector(toggleLogin), keyEquivalent: "")
    private let aboutItem = NSMenuItem(title: NSLocalizedString("About This App", comment: ""), action: #selector(showAbout), keyEquivalent: "")
    private let quitItem = NSMenuItem(title: NSLocalizedString("Quit", comment: ""), action: #selector(quit), keyEquivalent: "")
    private let preferences: Preferences
    private let overlay: OverlayController
    var issue: ((String) -> Void)?
    var probeDescription: String? { didSet { refresh() } }

    init(preferences: Preferences, overlay: OverlayController) {
        self.preferences = preferences
        self.overlay = overlay
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        menu.autoenablesItems = false
        menu.delegate = self
        for item in [hideItem, loginItem] { item.target = self; menu.addItem(item) }
        menu.addItem(.separator())
        for item in [aboutItem, quitItem] { item.target = self; menu.addItem(item) }
        statusItem.menu = menu
        refresh()
    }

    func menuWillOpen(_ menu: NSMenu) { refresh() }

    private func refresh() {
        hideItem.state = preferences.enabled ? .on : .off
        let stateDescription = preferences.enabled ? NSLocalizedString("Hide Notch: On", comment: "") : NSLocalizedString("Hide Notch: Off", comment: "")
        statusItem.button?.image = StatusIcon.image(hidingNotch: preferences.enabled)
        let variant = Bundle.main.object(forInfoDictionaryKey: "MaskedNotchRefreshVariant") as? String
        statusItem.button?.title = LayeredBandStack.configured ? NSLocalizedString(" Layered", comment: "") :
            DesktopBandPlacement.configured == .aboveWallpaper ? NSLocalizedString(" Background", comment: "") :
            variant == "blink" ? NSLocalizedString(" Blink", comment: "") : variant == "redraw" ? " A" : variant == "order" ? " B" : ""
        statusItem.button?.toolTip = "Masked Notch — \(stateDescription)" + (probeDescription.map { String(format: NSLocalizedString("\nTest: %@", comment: ""), $0) } ?? "")
        statusItem.button?.setAccessibilityLabel("Masked Notch — \(stateDescription)")
        loginItem.isEnabled = true
        switch SMAppService.mainApp.status {
        case .enabled: loginItem.state = .on; loginItem.title = NSLocalizedString("Launch at Login", comment: "")
        case .requiresApproval: loginItem.state = .mixed; loginItem.title = NSLocalizedString("Launch at Login (Approval Required)", comment: "")
        case .notRegistered: loginItem.state = .off; loginItem.title = NSLocalizedString("Launch at Login", comment: "")
        case .notFound: loginItem.state = .off; loginItem.title = NSLocalizedString("Launch at Login (Unavailable)", comment: "")
        @unknown default: loginItem.state = .off; loginItem.title = NSLocalizedString("Launch at Login (Status Unknown)", comment: ""); loginItem.isEnabled = false
        }
        Diagnostics.record("menu hide=\(preferences.enabled) login=\(SMAppService.mainApp.status.rawValue) items=\(menu.items.count)")
    }

    @objc private func toggleHidden() {
        preferences.enabled.toggle()
        Diagnostics.event("menu hideNotch=\(preferences.enabled)")
        overlay.setEnabled(preferences.enabled)
        refresh()
    }

    @objc private func toggleLogin() {
        do {
            switch SMAppService.mainApp.status {
            case .enabled, .requiresApproval: try SMAppService.mainApp.unregister()
            case .notRegistered, .notFound: try SMAppService.mainApp.register()
            @unknown default: issue?(NSLocalizedString("Could not read the login item status.", comment: ""))
            }
            if SMAppService.mainApp.status == .requiresApproval {
                issue?(NSLocalizedString("Launch at login requires approval. Allow Masked Notch in System Settings → General → Login Items & Extensions. Click the pending menu item again to unregister it.", comment: ""))
            }
        } catch { issue?(String(format: NSLocalizedString("Could not update the login item.\n%@", comment: ""), error.localizedDescription)) }
        refresh()
    }

    @objc private func showAbout() {
        let bundle = Bundle.main
        let variant = bundle.object(forInfoDictionaryKey: "MaskedNotchRefreshVariant") as? String
        let mode: String
        if LayeredBandStack.configured {
            mode = NSLocalizedString("Three layered rendering methods", comment: "")
        } else {
            switch variant {
            case "blink": mode = NSLocalizedString("Blink test", comment: "")
            case "redraw": mode = NSLocalizedString("Redraw test (A)", comment: "")
            case "order": mode = NSLocalizedString("Window ordering test (B)", comment: "")
            default: mode = NSLocalizedString("Single black band", comment: "")
            }
        }
        let details = String(format: NSLocalizedString("A menu bar app that displays a black band over the notch area.\nYour wallpaper images, videos, and settings are left unchanged.\n\nRendering mode: %@\n\nRunning app location:\n%@", comment: ""), mode, bundle.bundlePath)
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "Masked Notch",
            .applicationVersion: bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? NSLocalizedString("Unknown", comment: ""),
            .version: bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? NSLocalizedString("Unknown", comment: ""),
            .credits: NSAttributedString(string: details, attributes: [.font: NSFont.systemFont(ofSize: 12)])
        ])
        NSApp.activate()
        Diagnostics.event("menu about opened")
    }

    @objc private func quit() { overlay.stop(); NSApp.terminate(nil) }
    func stop() { NSStatusBar.system.removeStatusItem(statusItem) }
}
