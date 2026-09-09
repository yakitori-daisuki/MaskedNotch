# Masked Notch

English | [日本語](README.ja.md)

A small Swift/AppKit menu bar app that draws a black strip across the top of a built-in notched display. It leaves wallpaper, aerial videos, and screensaver settings alone.

> **Experimental:** the strip can disappear after initially working. This remains unresolved, including in the layered Desktop experiment. Real lock-screen visibility and authentication remain unverified. Successful builds and tests do not establish visual reliability. See the [development record (Japanese)](docs/DEVELOPMENT_STATUS.ja.md) and [manual checklist](docs/MANUAL_TESTS.md).

## Requirements

- macOS 26 or later and an Apple Silicon Mac with a notched built-in display.
- To build: full Xcode with the macOS 26 SDK; locally verified with Xcode 26.5.
- No XcodeGen, Homebrew packages, or external Swift package downloads are needed.

External, mirrored, offline, and non-notched displays are excluded. Menus support English and Japanese, following macOS language preferences with English as the fallback. Restart after changing the language.

## Build and run

From the repository folder:

Get the source with `git clone https://github.com/yakitori-daisuki/MaskedNotch.git`, then `cd MaskedNotch`. For this working folder's separate GitHub account configuration, see the [setup notes (Japanese)](docs/GITHUB_SETUP.ja.md).

```sh
./script/build_and_run.sh --build  # Build Debug without launching
./script/build_and_run.sh --probe # Test launch; exits after 90 seconds
./script/build_and_run.sh         # Normal launch
```

Alternatively, open `MaskedNotch.xcodeproj`, choose the `MaskedNotch` scheme and My Mac, then Run. The checked-in project is ready to use. `Package.swift` builds only the core library and tests, not the GUI app.

The Debug app is at `build/DerivedData/Build/Products/Debug/MaskedNotch.app`. To build Release:

```sh
MASKED_NOTCH_CONFIGURATION=Release ./script/build_and_run.sh --build
```

The Release app is at `build/DerivedData/Build/Products/Release/MaskedNotch.app`. Copy it to a stable location such as `~/Applications` before testing login launch. Build-only mode does not quit, install, or launch apps. Launch modes quit an existing `MaskedNotch` process first.

## Create a self-contained installer

Following the approach in [Quick3DLook](https://github.com/yakitori-daisuki/Quick3DLook/blob/main/README.ja.md), build locally and distribute a script containing the app plus a separate SHA-256 file:

```sh
./script/build_unsigned_installer.sh
```

Outputs:

- `dist/MaskedNotch-install-unsigned.sh`
- `dist/MaskedNotch-install-unsigned.sh.sha256`

This builds the **standard** arm64 Release app, verifies its ad-hoc signature, hardened runtime, architecture, resources, and absence of entitlements, then embeds its ZIP. It does not package the A/B, Blink, or Desktop experiments or install/launch anything on the build machine. Recipients need only macOS's built-in tools, with no Xcode, Homebrew, developer account, or signing certificate.

### Install a downloaded build

**No public installer release is available yet.** These instructions apply after receiving both files together or downloading them from a release. See the [release guide](docs/RELEASING.md).

This build is **not Developer ID signed or notarized by Apple**. Ad-hoc signing does not identify the publisher. Only install from a source you trust. `--allow-unsigned` explicitly permits removing this app's quarantine attribute; it does not change Gatekeeper or SIP settings. Checksums from the same source detect damage or mismatches, not a compromised publisher.

In the folder containing both files:

```sh
shasum -a 256 -c MaskedNotch-install-unsigned.sh.sha256
```

Continue only after `MaskedNotch-install-unsigned.sh: OK`. You can inspect the script before running it. Quit Masked Notch and experimental variants, then install:

```sh
bash MaskedNotch-install-unsigned.sh --user --allow-unsigned
```

This installs to `~/Applications/Masked Notch.app`. Use `--system` for writable `/Applications`; do not use `sudo`. Existing installations are retained as timestamped backups. Add `--no-open` to skip launching after installation. Login launch is not enabled automatically.

To verify the embedded payload and signature without installing or launching:

```sh
bash MaskedNotch-install-unsigned.sh --verify-only
```

## Use

The menu contains **Hide Notch**, **Launch at Login**, **About**, and **Quit**. Hide Notch starts on and is saved. Login launch is off until enabled explicitly; approval may be required in System Settings → General → Login Items & Extensions. There is no Dock icon or main window.

For initial desktop testing, turn off **Show menu bar background** under Menu Bar and **Reduce transparency** under Accessibility → Display. The app does not change these settings. These settings alone do not resolve the disappearance issue.

Check that menus, clock, and icons remain readable and clickable with your wallpaper and appearance. The app does not control system text color. If anything is obscured, disable Hide Notch or quit. The icon reflects the saved setting, not the rendered result.

Lock-screen support uses private SkyLight APIs in your already logged-in session. Pre-login, FileVault unlock, and other users' sessions are excluded. OS updates may break it. Start with the 90-second probe and [manual checklist](docs/MANUAL_TESTS.md); lock-screen behavior is not a verified feature.

## Tests and diagnostics

```sh
./script/test.sh
./script/test.sh --xcode
python3 script/check_vendor.py
python3 script/test_localizations.py build/ReleaseDerivedData/Build/Products/Release/MaskedNotch.app
python3 script/test_unsigned_installer.py # Build installer first
./script/build_and_run.sh --inspect       # Read-only; no build or launch
```

Localization checks use a small Foundation helper without launching the main app or changing saved language preferences. Tests do not verify final appearance, real clicks, login-item registration, or authentication. Experiments and limitations are recorded in [docs](docs/).

## Remove

Disable Launch at Login, quit, then move the app to the Trash. Check macOS Login Items if needed. Wallpaper restoration is unnecessary. Emergency stop: `pkill -x MaskedNotch` (also stops experimental variants). Delete backup apps manually when no longer needed.

## Project and license

`Sources/MaskedNotch/` contains the app and lock-screen bridge; `Sources/MaskedNotchCore/` contains geometry/state logic. `Tests/` contains core and AppKit tests; `script/` contains build, package, and diagnostic tools.

[MIT License](LICENSE). A pinned, modified portion of [SkyLightWindow](https://github.com/Lakr233/SkyLightWindow) is bundled under MIT; see [third-party notices](THIRD_PARTY_NOTICES.md). The app has no networking or analytics code. Screen capture exists only in a separate developer diagnostic script, not the application.
