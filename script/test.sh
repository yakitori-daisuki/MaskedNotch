#!/bin/bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"
mkdir -p build
swift test --scratch-path build/SwiftPM > build/core-tests.log 2>&1 || { cat build/core-tests.log; exit 1; }
tail -8 build/core-tests.log
if [[ "${1:-}" == --xcode ]]; then
    xcodebuild -project MaskedNotch.xcodeproj -scheme MaskedNotch -configuration Debug \
      -derivedDataPath build/DerivedData -destination 'platform=macOS' \
      -parallel-testing-enabled NO test > build/xcode-tests.log 2>&1 || { tail -100 build/xcode-tests.log; exit 1; }
    tail -12 build/xcode-tests.log
fi
