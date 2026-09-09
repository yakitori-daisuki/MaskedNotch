import AppKit

/// Owns three desktop bands plus, briefly, one retiring replacement. All remain
/// below system menu glyphs. No wallpaper settings or lock Spaces are touched.
final class LayeredBandStack {
    static var configured: Bool {
        Bundle.main.object(forInfoDictionaryKey: "MaskedNotchLayeredBands") as? Bool == true
    }

    private let frame: CGRect
    private let displayID: CGDirectDisplayID
    private let menuScope: DesktopBandScope
    private let present: (BandPanel, CGDirectDisplayID) -> Bool
    private var bases: [BandPanel] = []
    private var menuBand: BandPanel?
    private var retiring: BandPanel?
    private var retirement: DispatchWorkItem?
    private var generation = 0
    private var closed = false
    private var pendingBaseRefresh: [Int] = []
    private var pendingMenuRefresh = false

    var panels: [BandPanel] { bases + [menuBand, retiring].compactMap { $0 } }

    /// Renew every rendering surface after a Space transition. Coalesce rapid
    /// switches; the latest request must refresh both bases and the menu band.
    func requestSpaceRefresh() {
        guard !closed else { return }
        pendingBaseRefresh = [0, 1]
        pendingMenuRefresh = true
        Diagnostics.event("layered Space refresh requested")
    }

    init(frame: CGRect, displayID: CGDirectDisplayID, menuScope: DesktopBandScope = .allDesktops,
         present: @escaping (BandPanel, CGDirectDisplayID) -> Bool = { panel, display in
             panel.restoreDesktopOrder(displayID: display)
             return panel.isVisible
         }) {
        self.frame = frame
        self.displayID = displayID
        self.menuScope = menuScope
        self.present = present
        bases = [
            BandPanel(frame: frame, locked: false, desktopPlacement: .wallpaperSurface, rendering: .windowFill),
            BandPanel(frame: frame, locked: false, desktopPlacement: .aboveWallpaper, rendering: .layerPixels),
        ]
        menuBand = makeMenuBand()
    }

    /// Ordinary events reassert surfaces; Space transitions queue a bounded
    /// renewal. The desktop timer also replaces the menu band periodically.
    func refresh(replaceMenu: Bool = false) {
        guard !closed else { return }
        for panel in bases { _ = present(panel, displayID) }
        let baseIndex = pendingBaseRefresh.first
        if retiring == nil, baseIndex != nil || pendingMenuRefresh || replaceMenu,
           let previous = baseIndex.map({ bases[$0] }) ?? menuBand {
            let next = baseIndex.map { index in
                BandPanel(frame: frame, locked: false,
                          desktopPlacement: index == 0 ? .wallpaperSurface : .aboveWallpaper,
                          rendering: index == 0 ? .windowFill : .layerPixels)
            } ?? makeMenuBand()
            // Keep the previous band if AppKit cannot order in its replacement.
            guard present(next, displayID) else {
                next.orderOut(nil)
                next.close()
                _ = present(previous, displayID)
                Diagnostics.event("layered replacement could not be ordered; kept previous band")
                return
            }
            if let baseIndex {
                bases[baseIndex] = next
                pendingBaseRefresh.removeFirst()
            } else {
                menuBand = next
                pendingMenuRefresh = false
            }
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
            // The other two bands and the replacement remain throughout.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: work)
            Diagnostics.record("layered replaced rendering=\(next.rendering.rawValue) window=\(next.windowNumber) retiring=\(previous.windowNumber) activeSpace=\(next.isOnActiveSpace) count=\(panels.count)")
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
        pendingBaseRefresh.removeAll()
        pendingMenuRefresh = false
        for panel in panels {
            panel.orderOut(nil)
            panel.close()
        }
        bases.removeAll()
        menuBand = nil
        retiring = nil
    }

    private func makeMenuBand() -> BandPanel {
        BandPanel(frame: frame, locked: false, desktopPlacement: .underMenu, rendering: .quartzFill,
                  desktopScope: menuScope)
    }

    deinit { close() }
}
