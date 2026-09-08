import AppKit

/// Owns three desktop bands plus, briefly, one retiring replacement. All remain
/// below system menu glyphs. No wallpaper settings or lock Spaces are touched.
final class LayeredBandStack {
    static var configured: Bool {
        Bundle.main.object(forInfoDictionaryKey: "MaskedNotchLayeredBands") as? Bool == true
    }

    private let frame: CGRect
    private let displayID: CGDirectDisplayID
    private let present: (BandPanel, CGDirectDisplayID) -> Bool
    private var bases: [BandPanel] = []
    private var menuBand: BandPanel?
    private var retiring: BandPanel?
    private var retirement: DispatchWorkItem?
    private var generation = 0
    private var closed = false

    var panels: [BandPanel] { bases + [menuBand, retiring].compactMap { $0 } }

    init(frame: CGRect, displayID: CGDirectDisplayID,
         present: @escaping (BandPanel, CGDirectDisplayID) -> Bool = { panel, display in
             panel.restoreDesktopOrder(displayID: display)
             return panel.isVisible
         }) {
        self.frame = frame
        self.displayID = displayID
        self.present = present
        bases = [
            BandPanel(frame: frame, locked: false, desktopPlacement: .wallpaperSurface, rendering: .windowFill),
            BandPanel(frame: frame, locked: false, desktopPlacement: .aboveWallpaper, rendering: .layerPixels),
        ]
        menuBand = makeMenuBand()
    }

    /// Events reassert all three surfaces. Replacement is requested only by the
    /// guarded desktop timer, so repeated activation notifications cannot churn windows.
    func refresh(replaceMenu: Bool = false) {
        guard !closed else { return }
        for panel in bases { _ = present(panel, displayID) }
        if replaceMenu, retiring == nil, let previous = menuBand {
            let next = makeMenuBand()
            // Keep the previous band if AppKit cannot order in its replacement.
            guard present(next, displayID) else {
                next.orderOut(nil)
                next.close()
                _ = present(previous, displayID)
                Diagnostics.event("layered replacement could not be ordered; kept previous band")
                return
            }
            menuBand = next
            retiring = previous
            let ticket = generation
            let work = DispatchWorkItem { [weak self, weak previous] in
                guard let self, self.generation == ticket, !self.closed,
                      let previous, self.retiring === previous else { return }
                previous.orderOut(nil)
                previous.close()
                self.retiring = nil
                self.retirement = nil
            }
            retirement = work
            // Both base bands and the replacement remain in place throughout.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: work)
            Diagnostics.record("layered replaced menu window=\(next.windowNumber) retiring=\(previous.windowNumber) count=\(panels.count)")
        } else if let menuBand {
            _ = present(menuBand, displayID)
        }
    }

    func close() {
        guard !closed else { return }
        closed = true
        generation += 1
        retirement?.cancel()
        retirement = nil
        for panel in panels {
            panel.orderOut(nil)
            panel.close()
        }
        bases.removeAll()
        menuBand = nil
        retiring = nil
    }

    private func makeMenuBand() -> BandPanel {
        BandPanel(frame: frame, locked: false, desktopPlacement: .underMenu, rendering: .quartzFill)
    }

    deinit { close() }
}
