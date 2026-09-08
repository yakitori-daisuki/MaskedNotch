# Build 4 redraw fix — 2026-09-08

The previous timer fired approximately every 0.5 seconds, but the 24 observed
calls to the redraw method did not invoke BlackView.updateLayer. Marking an
occluded view dirty and calling displayIfNeeded was insufficient evidence of
new content being submitted. This is separate from the unresolved z-order issue.

The redraw now creates a fresh opaque black 1×1 CGImage and assigns it to the
full-width layer's contents, with implicit animations disabled and a transaction
flush. It does not blink, hide/show, alter wallpaper, or change window levels.
The bitmap stretches over the band. Allocation failure returns safely.

On the current Mac, build 4 diagnostic logs recorded 20 periodic callbacks and
20 matching pixel submissions in a 10-second interval. See
evidence/redraw-verification-build4.log. These logs are disabled in normal use.
Release build, strict signature check and 28 Xcode tests passed (20 core tests
also passed). The new regression test verifies new image identity and opaque
black bytes even with the panel never ordered onscreen.

This verifies application-side submission, not WindowServer's final pixels,
menu readability, or sustained visual success. Previous CPU measurements apply
to the old redraw implementation; build 4 performance is not yet measured.
