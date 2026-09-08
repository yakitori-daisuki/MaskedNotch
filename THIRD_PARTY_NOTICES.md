# Third-party notices

## Incorporated code: SkyLightWindow

- Upstream: https://github.com/Lakr233/SkyLightWindow
- Fixed commit: **a28588bc5222b8daf6c4b46afb462a5d31495685**
- Copyright (c) 2025 Lakr Aream
- License: MIT, complete text in `Vendor/SkyLightWindow/LICENSE`.
- Reviewed source: `Sources/SkyLightWindow/SkyLightOperator.swift` and the window/view helpers.
- Modified derivative compiled into this app: `Sources/MaskedNotch/LockScreen/SkyLightBridge.swift`.
- The exact upstream source snapshot and package manifests are retained under `Vendor/SkyLightWindow` for comparison. They are **not** Xcode source members or a resolved SwiftPM dependency.

Changes: guarded `dlopen`/`dlsym`, connection and return-value validation, throwing errors,
one lazily created/reused Space, explicit hiding on removal, fail-closed lock rendering,
and lifetime-scoped dynamic library handle. The app uses its own small input-transparent
AppKit panel. No upstream fullscreen window, SwiftUI hosting, singleton operator,
`makeKeyAndOrderFront`, or near-`Int32.max` window level is incorporated into the executable.

The upstream Swift 5.9 manifest has no dependencies. The Swift 6.1 manifest declares
OpenSwiftUI-spm from 0.19.2 (or environment-selected source alternatives), with a product
conditioned on the OpenSwiftUI trait. Vendoring the small AppKit integration avoids resolving
that dependency graph entirely. Masked Notch has no external package dependency.

## Read as design references; no source incorporated

| Project | Reviewed version | License at that version | What was checked |
|---|---|---|---|
| TheBoredTeam/boring.notch | `99900bf630a3d3e97fae079df2175993318d51f7` | GPL-3.0, LICENSE | Lock/unlock notification names, enabling SkyLight only while locked, removal on unlock |
| jordanbaird/Ice PR #960 | head `48846c39d0b37674c1d0025079b82ca5263742d2` | GPL-3.0, LICENSE | `statusBar - 1` backdrop candidate, OS setting caveats, overlay window behavior |

References:
- https://github.com/TheBoredTeam/boring.notch/blob/99900bf630a3d3e97fae079df2175993318d51f7/boringNotch/boringNotchApp.swift
- https://github.com/TheBoredTeam/boring.notch/blob/99900bf630a3d3e97fae079df2175993318d51f7/boringNotch/components/Notch/BoringNotchSkyLightWindow.swift
- https://github.com/TheBoredTeam/boring.notch/blob/99900bf630a3d3e97fae079df2175993318d51f7/LICENSE
- https://github.com/jordanbaird/Ice/pull/960
- https://github.com/jordanbaird/Ice/blob/48846c39d0b37674c1d0025079b82ca5263742d2/Ice/MenuBar/Appearance/MenuBarOverlayPanel.swift
- https://github.com/jordanbaird/Ice/blob/48846c39d0b37674c1d0025079b82ca5263742d2/LICENSE

Their app/package dependency graphs are not imported. Boring Notch's Defaults/Combine/
SwiftUI window wrappers and Ice's wallpaper reads, private sticky tags, AX, polling and
background settings SPI are not used. Notifications, constants, and public API behavior
were used as factual references; this is not a fork of either application.

Upstream behavior is evidence of an implementation technique, not a guarantee of Masked
Notch's lock-screen visibility, authentication safety, or OS compatibility.
