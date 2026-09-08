#!/bin/bash
# Build only: never stop, install, or launch an app on the build machine.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build dist
xcodebuild -project MaskedNotch.xcodeproj -scheme MaskedNotch \
  -configuration Release -derivedDataPath build/ReleaseDerivedData \
  -destination 'generic/platform=macOS' ARCHS=arm64 ONLY_ACTIVE_ARCH=NO \
  CODE_SIGN_IDENTITY=- CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO \
  build > build/release-build.log 2>&1 || { tail -80 build/release-build.log; exit 1; }
python3 script/package_unsigned_installer.py
