import AppKit
import OSLog

final class OverlayController {
    private(set) var state: DisplayState
    private let session = SessionMonitor()
    private var panel: BandPanel?
    private var layeredStack: LayeredBandStack?
    private var layeredTicks = 0
    private let usesLayeredBands = LayeredBandStack.configured
    private let variantRefresh = VariantRefresh()
    private let blinkPulse = BlinkPulse()
    private let desktopPlacement = DesktopBandPlacement.configured
    private let usesBlink = Bundle.main.object(forInfoDictionaryKey: "MaskedNotchRefreshVariant") as? String == "blink"
    private let variantPhase: RefreshProbe.Phase? = {
        // Keep the wallpaper-layer experiment continuously visible, without a timer.
        if DesktopBandPlacement.configured == .aboveWallpaper { return nil }
        // Keep the timed A/B comparison isolated from the normal refresh timer.
        if ProcessInfo.processInfo.arguments.contains("--probe-refresh") { return nil }
        return (Bundle.main.object(forInfoDictionaryKey: "MaskedNotchRefreshVariant") as? String)
            .flatMap(RefreshProbe.Phase.init(rawValue:)) ?? .redraw
    }()
    private var shownMode: DisplayMode = .hidden
    private var shownGeometry: DisplayGeometry?
    private var bridge: SkyLightBridge?
    private var observers: [(NotificationCenter, NSObjectProtocol)] = []
    private var retries: [DispatchWorkItem] = []
    private var presentationObservation: NSKeyValueObservation?
    private var activeSpaceObservation: NSKeyValueObservation?
    private let logger = Logger(subsystem: "local.MaskedNotch", category: "Overlay")
    var issue: ((String) -> Void)?
    var unlocked: (() -> Void)?
    var willHideForSession: (() -> Void)?

    init(enabled: Bool) { state = DisplayState(enabled: enabled) }

    func start() {
        guard observers.isEmpty, !state.terminating else { return }
        session.changed = { [weak self] in self?.refreshWithRetries() }
        session.start()
        presentationObservation = NSApp.observe(\.currentSystemPresentationOptions, options: [.new]) { [weak self] _, _ in
            DispatchQueue.main.async { self?.refreshWithRetries() }
        }
        observe(NotificationCenter.default, NSApplication.didChangeScreenParametersNotification) { $0.refreshWithRetries() }
        observe(NotificationCenter.default, NSApplication.didBecomeActiveNotification) { $0.refreshWithRetries() }
        observe(NotificationCenter.default, NSApplication.didResignActiveNotification) { $0.refreshWithRetries() }
        let workspace = NSWorkspace.shared.notificationCenter
        observe(workspace, NSWorkspace.activeSpaceDidChangeNotification) { $0.refreshWithRetries() }
        observe(workspace, NSWorkspace.didActivateApplicationNotification) { $0.refreshWithRetries() }
        observe(workspace, NSWorkspace.sessionDidResignActiveNotification) {
            $0.state.ownConsole = false; $0.cancelRetries(); $0.willHideForSession?(); $0.withdraw()
            $0.refreshWithRetries()
        }
        observe(workspace, NSWorkspace.willPowerOffNotification) { $0.stop(); NSApp.terminate(nil) }
        observe(workspace, NSWorkspace.sessionDidBecomeActiveNotification) { $0.refreshWithRetries() }
        for name in [NSWorkspace.willSleepNotification, NSWorkspace.screensDidSleepNotification] {
            observe(workspace, name) { $0.state.sleeping = true; $0.cancelRetries(); $0.willHideForSession?(); $0.withdraw() }
        }
        for name in [NSWorkspace.didWakeNotification, NSWorkspace.screensDidWakeNotification] {
            observe(workspace, name) { $0.state.sleeping = false; $0.refreshWithRetries() }
        }
        refreshWithRetries()
    }

    func setEnabled(_ enabled: Bool) {
        state.enabled = enabled
        refreshWithRetries()
    }

    /// Development experiment only. Reuses the current desktop panel and never revives it.
    func performRefreshProbe(_ phase: RefreshProbe.Phase) -> Bool {
        guard phase != .baseline, state.mode == .desktop, shownMode == .desktop,
              let panel, panel.isVisible, let geometry = shownGeometry else { return false }
        let currentSession = session.snapshot()
        guard currentSession.ownConsole, currentSession.locked == false,
              ScreenProvider.target()?.0 == geometry else { return false }
        let options = NSApp.currentSystemPresentationOptions
        guard !options.contains(.fullScreen), !options.contains(.hideMenuBar) else { return false }
        switch phase {
        case .baseline: return false
        case .redraw: panel.redrawBlackSurface()
        case .order: panel.restoreDesktopOrder(displayID: geometry.id, redraw: false)
        }
        return true
    }

    var canPresentAlert: Bool {
        let current = session.snapshot()
        return current.ownConsole && current.locked == false && !state.sleeping && !state.terminating
    }

    private func performBlink() {
        // Reuse the existing desktop/session/fullscreen eligibility checks.
        guard !blinkPulse.isPending, performRefreshProbe(.redraw),
              let panel, let geometry = shownGeometry else { return }
        let ticket = state.generation
        blinkPulse.begin(hide: { panel.orderOut(nil) }, show: { [weak self, weak panel] in
            guard let self, let panel, self.panel === panel,
                  self.state.accepts(ticket), self.state.mode == .desktop,
                  self.shownMode == .desktop, self.canPresentAlert,
                  ScreenProvider.target()?.0 == geometry else { return }
            let options = NSApp.currentSystemPresentationOptions
            guard !options.contains(.fullScreen), !options.contains(.hideMenuBar) else { return }
            panel.restoreDesktopOrder(displayID: geometry.id)
            Diagnostics.record("blink reappeared")
        })
        Diagnostics.record("blink hidden for 100ms")
    }

    private func refreshLayeredBands() {
        guard !state.terminating, !state.sleeping, state.enabled,
              shownMode == .desktop, let stack = layeredStack,
              let geometry = shownGeometry else {
            variantRefresh.stop()
            return
        }
        let current = session.snapshot()
        let options = NSApp.currentSystemPresentationOptions
        guard current.ownConsole, current.locked == false,
              ScreenProvider.target()?.0 == geometry,
              !options.contains(.fullScreen), !options.contains(.hideMenuBar) else {
            // Reevaluate mode before any ordering or replacement. A missed lock,
            // display, or fullscreen notification must not revive desktop bands.
            refreshWithRetries()
            return
        }
        layeredTicks += 1
        stack.refresh(replaceMenu: layeredTicks % 2 == 0)
        Diagnostics.record("layered tick=\(layeredTicks) count=\(stack.panels.count)")
    }

    func refreshWithRetries() {
        cancelRetries()
        refresh()
        let ticket = state.generation
        guard state.enabled, !state.terminating, !state.sleeping else { return }
        for delay in [0.15, 0.5, 1.5] {
            let work = DispatchWorkItem { [weak self] in
                guard let self, self.state.accepts(ticket) else { return }
                self.refresh()
            }
            retries.append(work)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
        }
    }

    private func refresh() {
        let snapshot = session.snapshot()
        state.ownConsole = snapshot.ownConsole
        state.locked = snapshot.locked
        if !canPresentAlert { willHideForSession?() }
        let target = ScreenProvider.target()
        state.targetAvailable = target != nil
        // Public hints are not a per-display fullscreen oracle. .fullScreenNone prevents
        // fullscreen conversion, while no fullScreenAuxiliary flag avoids opting into it.
        let options = NSApp.currentSystemPresentationOptions
        state.desktopSuppressed = options.contains(.fullScreen) || options.contains(.hideMenuBar)
        let mode = state.mode
        Diagnostics.record("refresh ownConsole=\(state.ownConsole) locked=\(String(describing: state.locked)) mode=\(mode) target=\(String(describing: target?.0))")
        guard mode != .hidden, let (geometry, frame) = target else {
            withdraw()
            if canPresentAlert { unlocked?() }
            return
        }
        if mode != shownMode || geometry != shownGeometry || (panel == nil && layeredStack == nil) {
            withdraw()
            if mode == .desktop && usesLayeredBands {
                let stack = LayeredBandStack(frame: frame, displayID: geometry.id)
                layeredStack = stack
                shownMode = mode
                shownGeometry = geometry
                stack.refresh()
                // A base band survives replacement of the upper band.
                observeActiveSpace(of: stack.panels[0])
                for band in stack.panels {
                    Diagnostics.event("band created mode=desktop rendering=\(band.rendering.rawValue) level=\(band.level.rawValue) visible=\(band.isVisible) activeSpace=\(band.isOnActiveSpace) window=\(band.windowNumber)")
                }
            } else {
                let next = BandPanel(frame: frame, locked: mode == .locked, desktopPlacement: desktopPlacement)
                do {
                    if mode == .locked {
                        if bridge == nil { bridge = try SkyLightBridge() }
                        guard let bridge else { throw SkyLightFailure.unavailable("bridge") }
                        try bridge.attach(next)
                    }
                    panel = next
                    shownMode = mode
                    shownGeometry = geometry
                    if mode == .locked { next.orderFrontRegardless() }
                    else { next.restoreDesktopOrder(displayID: geometry.id) }
                    observeActiveSpace(of: next)
                    Diagnostics.record("ordered mode=\(mode) desktopPlacement=\(desktopPlacement.rawValue) level=\(next.level.rawValue) visible=\(next.isVisible) key=\(next.isKeyWindow) mouseIgnored=\(next.ignoresMouseEvents) frame=\(frame)")
                    Diagnostics.event("band created mode=\(mode) level=\(next.level.rawValue) visible=\(next.isVisible) activeSpace=\(next.isOnActiveSpace) window=\(next.windowNumber)")
                    logger.info("Band ordered: mode=\(String(describing: mode), privacy: .public) display=\(geometry.id) frame=\(String(describing: frame), privacy: .public)")
                } catch {
                    next.orderOut(nil); next.close()
                    state.lockUnavailable = true
                    withdraw()
                    logger.error("Lock band failed: \(error.localizedDescription, privacy: .public)")
                    issue?(error.localizedDescription)
                    Diagnostics.record("lock-failure \(error.localizedDescription)")
                }
            }
        }
        // Geometry may be unchanged even after WindowServer changes same-level ordering.
        if mode == .desktop, let stack = layeredStack {
            stack.refresh()
            variantRefresh.start { [weak self] in self?.refreshLayeredBands() }
        } else if mode == .desktop, let panel {
            panel.restoreDesktopOrder(displayID: geometry.id)
            if let phase = variantPhase, phase != .baseline {
                variantRefresh.start { [weak self] in
                    if self?.usesBlink == true { self?.performBlink(); return }
                    let applied = self?.performRefreshProbe(phase) ?? false
                    Diagnostics.record("refresh-tick phase=\(phase.rawValue) applied=\(applied)")
                }
            } else { variantRefresh.stop() }
        } else { variantRefresh.stop() }
        if canPresentAlert { unlocked?() }
    }

    private func withdraw() {
        blinkPulse.cancel()
        variantRefresh.stop()
        activeSpaceObservation?.invalidate()
        activeSpaceObservation = nil
        let count = (layeredStack?.panels.count ?? 0) + (panel == nil ? 0 : 1)
        if count > 0 {
            Diagnostics.event("band withdrawn count=\(count) previous=\(shownMode) enabled=\(state.enabled) sleeping=\(state.sleeping) ownConsole=\(state.ownConsole) locked=\(String(describing: state.locked)) target=\(state.targetAvailable) suppressed=\(state.desktopSuppressed) lockUnavailable=\(state.lockUnavailable) terminating=\(state.terminating)")
        }
        layeredStack?.close()
        layeredStack = nil
        layeredTicks = 0
        panel?.orderOut(nil)
        panel?.close()
        panel = nil
        if bridge?.teardown() == false {
            state.lockUnavailable = true
            issue?(NSLocalizedString("The lock-screen Space cleanup failed. The band windows have been closed. Please restart the app.", comment: ""))
        }
        shownMode = .hidden
        shownGeometry = nil
    }

    private func observeActiveSpace(of panel: BandPanel) {
        activeSpaceObservation = panel.observe(\.isOnActiveSpace, options: [.new]) { [weak self] _, _ in
            guard self?.blinkPulse.isPending != true else { return }
            DispatchQueue.main.async { self?.refreshWithRetries() }
        }
    }

    private func cancelRetries() {
        state.invalidate()
        retries.forEach { $0.cancel() }
        retries.removeAll()
    }

    private func observe(_ center: NotificationCenter, _ name: Notification.Name,
                         action: @escaping (OverlayController) -> Void) {
        observers.append((center, center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
            if let self { action(self) }
        }))
    }

    func stop() {
        state.terminating = true
        cancelRetries()
        withdraw()
        session.stop()
        observers.forEach { $0.0.removeObserver($0.1) }
        observers.removeAll()
        presentationObservation?.invalidate()
        presentationObservation = nil
        bridge = nil
    }
}
