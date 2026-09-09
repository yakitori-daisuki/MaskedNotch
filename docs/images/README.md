# README app icon

`masked-notch-icon.png` is a PNG export of the standard app's compiled
`AppIcon.icns` (version 0.1.0, build 9). The original Icon Composer artwork is
in `Resources/IconArtwork/AppIcon.icon` and is covered by the project's GPL-3.0-only license.
Both language READMEs display the same image at 160 × 160 CSS pixels.

To refresh after changing the app icon, build the Release app and run from the
repository root:

```sh
sips -s format png build/ReleaseDerivedData/Build/Products/Release/MaskedNotch.app/Contents/Resources/AppIcon.icns --out docs/images/masked-notch-icon.png
```
