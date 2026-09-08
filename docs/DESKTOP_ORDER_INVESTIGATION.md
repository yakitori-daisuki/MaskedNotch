# Desktop order investigation — 2026-09-08

User requested app-side recovery without changing wallpaper or Thaw settings.
The current build and hideNotch=true were confirmed. Window metadata showed,
front-to-back, Window Server menu (level 24), Thaw background (level 24,
1800×44 pt), Masked Notch band (level 24, 1800×38 pt).

Two bounded 90-second probes were built and launched:

1. SLSOrderWindow(mainConnection, ownWindow, -1, systemMenuWindow).
2. SLSOrderWindow(mainConnection, ownWindow, +1, backgroundWindowBelowMenu).

The first returned 0 repeatedly, but public window metadata still showed the
band behind Thaw. The second also failed to improve the observed ordering.
Neither test raised window levels, changed another process's window, or changed
wallpaper/settings. API success did not prove visual success. The experimental
bridge was removed from the production target and normal A rendering restored.

Thaw interference remains a hypothesis until a controlled comparison without
its background is possible. No stable black rendering or interaction success is
claimed. Pure-black overlays above system menu content are not an acceptable fix.

References inspected:
- https://developer.apple.com/documentation/appkit/nswindow/order(_:relativeto:)
- https://github.com/NUIKit/CGSInternal/blob/master/CGSWindow.h (ABI reference only)
- https://github.com/sane-apps/SaneBar (MenuBarAppearanceService: translucent tint
  at statusBar level is not suitable for an opaque pure-black band).

No source from these additional projects was incorporated into the app.
