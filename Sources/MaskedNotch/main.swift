import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var overlay: OverlayController?
    private var statusMenu: StatusMenu?
    private var alerts: DeferredAlerts?
    private var probeTimer: DispatchSourceTimer?
    private var refreshProbe: RefreshProbe?
    private var refreshProbeStart: DispatchWorkItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let others = ["local.MaskedNotch", "local.MaskedNotch.A", "local.MaskedNotch.B", "local.MaskedNotch.Blink", "local.MaskedNotch.Desktop"]
            .flatMap { NSRunningApplication.runningApplications(withBundleIdentifier: $0) }
            .filter { $0.processIdentifier != getpid() }
        if !others.isEmpty {
            others.forEach { _ = $0.terminate() }
            waitForPreviousApplications(others, attempts: 30, notification: notification)
            return
        }
        let arguments = ProcessInfo.processInfo.arguments
        Diagnostics.enabled = arguments.contains("--diagnostics")
        let probeSeconds: Double? = {
            guard let index = arguments.firstIndex(of: "--probe-seconds"), index + 1 < arguments.count,
                  let value = Double(arguments[index + 1]), value.isFinite else { return nil }
            return min(300, max(5, value))
        }()
        Diagnostics.record("launch final probe=\(probeSeconds != nil)")
        let preferences = Preferences()
        Diagnostics.event("launch build=\(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown") placement=\(DesktopBandPlacement.configured.rawValue) layered=\(LayeredBandStack.configured) hideNotch=\(preferences.enabled)")
        let controller = OverlayController(enabled: preferences.enabled)
        let alerts = DeferredAlerts(overlay: controller)
        self.alerts = alerts
        overlay = controller
        controller.issue = { [weak alerts] in alerts?.enqueue($0) }
        controller.unlocked = { [weak alerts] in alerts?.presentIfPossible() }
        controller.willHideForSession = { [weak alerts] in alerts?.suspend() }
        let menu = StatusMenu(preferences: preferences, overlay: controller)
        menu.issue = { [weak alerts] in alerts?.enqueue($0) }
        statusMenu = menu

        if let seconds = probeSeconds {
            // Arm before private calls. A separate-queue fallback exits if main stalls.
            let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .utility))
            timer.schedule(deadline: .now() + seconds)
            timer.setEventHandler {
                DispatchQueue.main.async { NSApp.terminate(nil) }
                DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 3) { _exit(0) }
            }
            probeTimer = timer
            timer.resume()
            do {
                let probeBridge = try SkyLightBridge()
                Diagnostics.record("SkyLight symbol/connection probe succeeded; lock rendering NOT tested")
                if arguments.contains("--probe-lock-backend"), let (_, frame) = ScreenProvider.target() {
                    // Developer integration probe only: the panel is NEVER ordered onscreen.
                    let hiddenBand = BandPanel(frame: frame, locked: true)
                    defer { hiddenBand.orderOut(nil); hiddenBand.close(); _ = probeBridge.teardown() }
                    try probeBridge.attach(hiddenBand)
                    Diagnostics.record("SkyLight hidden-panel attach succeeded visible=\(hiddenBand.isVisible); lock rendering NOT tested")
                    hiddenBand.orderOut(nil)
                    hiddenBand.close()
                    Diagnostics.record("SkyLight hidden-panel cleanup succeeded=\(probeBridge.teardown())")
                }
            } catch { Diagnostics.record("SkyLight probe failed: \(error.localizedDescription)") }
        }
        controller.start()
        if arguments.contains("--probe-refresh"), let seconds = probeSeconds, seconds >= 110 {
            let experiment = RefreshProbe(step: { [weak controller] in controller?.performRefreshProbe($0) ?? false },
                                          changed: { [weak menu] in menu?.probeDescription = $0?.label })
            refreshProbe = experiment
            // Exclude launch and initial screen retries from the comparison baseline.
            let start = DispatchWorkItem { [weak experiment] in experiment?.start() }
            refreshProbeStart = start
            DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: start)
        }
        if probeSeconds == nil && !preferences.hasSeenIntroduction {
            let intro = NSLocalizedString("Your wallpaper is left unchanged. Begin testing with Show Menu Bar Background and Reduce Transparency turned off in System Settings. This app does not change these settings or automatically detect the menu bar background setting.\n\nCheck that the Apple menu, clock, and icons remain readable and clickable over the black band. macOS controls the text color, so readability may vary with the wallpaper and light or dark appearance. Turn off Hide Notch if there is a problem.\n\nThe lock-screen feature uses private APIs. Compatibility with aerial wallpapers, security indicators, Touch ID, and password unlock has not been verified on the actual lock screen. See the README for the time-limited test procedure.", comment: "")
            alerts.acknowledged = { message in
                if message == intro { preferences.hasSeenIntroduction = true }
            }
            alerts.enqueue(intro)
        }
    }
    private func waitForPreviousApplications(_ applications: [NSRunningApplication], attempts: Int,
                                             notification: Notification) {
        guard applications.contains(where: { !$0.isTerminated }) else {
            applicationDidFinishLaunching(notification)
            return
        }
        guard attempts > 0 else { NSApp.terminate(nil); return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.waitForPreviousApplications(applications, attempts: attempts - 1, notification: notification)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        refreshProbeStart?.cancel()
        refreshProbe?.stop()
        alerts?.stop()
        overlay?.stop()
        statusMenu?.stop()
        probeTimer?.cancel()
        Diagnostics.event("terminated; panels and observers removed")
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
