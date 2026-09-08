#!/bin/bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"
MODE="${1:-run}"
# Inspect the existing state before any build, kill, or launch changes it.
if [[ "$MODE" == --inspect ]]; then
  mkdir -p build/ModuleCache
  exec xcrun swift -module-cache-path build/ModuleCache script/inspect_system_state.swift
fi
MASKED_NOTCH_CONFIGURATION="${MASKED_NOTCH_CONFIGURATION:-Debug}"
case "$MODE" in --desktop|--probe-desktop) MASKED_NOTCH_CONFIGURATION=Release ;; esac
case "$MASKED_NOTCH_CONFIGURATION" in Debug|Release) ;; *) echo "MASKED_NOTCH_CONFIGURATION must be Debug or Release" >&2; exit 2;; esac
case "$MODE" in run|--build|--verify|--probe|--probe-backend|--probe-refresh|--desktop|--probe-desktop|--debug|--logs|--telemetry) ;; *) echo "usage: $0 [--build|--verify|--inspect|--probe|--probe-backend|--probe-refresh|--desktop|--probe-desktop|--debug|--logs|--telemetry]" >&2; exit 2;; esac
if [[ "$MODE" != --build ]]; then pkill -x MaskedNotch >/dev/null 2>&1 || true; fi
mkdir -p build
xcodebuild -project MaskedNotch.xcodeproj -scheme MaskedNotch -configuration "$MASKED_NOTCH_CONFIGURATION" -derivedDataPath build/DerivedData build > build/build.log 2>&1 || { tail -80 build/build.log; exit 1; }
APP_BUNDLE="$ROOT_DIR/build/DerivedData/Build/Products/$MASKED_NOTCH_CONFIGURATION/MaskedNotch.app"
echo "Build succeeded: $APP_BUNDLE"
case "$MODE" in
  --desktop|--probe-desktop)
    python3 script/package_variants.py --desktop
    APP_BUNDLE="$ROOT_DIR/build/Variants/Masked Notch Desktop.app"
    ;;
esac
case "$MODE" in
  --build) exit 0 ;;
  --debug) exec lldb -- "$APP_BUNDLE/Contents/MacOS/MaskedNotch" ;;
  --probe) /usr/bin/open -n "$APP_BUNDLE" --args --probe-seconds 90 --diagnostics ;;
  --probe-backend) /usr/bin/open -n "$APP_BUNDLE" --args --probe-seconds 15 --diagnostics --probe-lock-backend ;;
  --probe-refresh) /usr/bin/open -n "$APP_BUNDLE" --args --probe-seconds 110 --diagnostics --probe-refresh ;;
  --probe-desktop) /usr/bin/open -n "$APP_BUNDLE" --args --probe-seconds 20 --diagnostics ;;
  *) /usr/bin/open -n "$APP_BUNDLE" ;;
esac
case "$MODE" in
  --verify|--probe|--probe-backend|--probe-refresh|--probe-desktop) sleep 2; pgrep -x MaskedNotch ;;
  --logs|--telemetry) exec /usr/bin/log stream --level info --style compact --predicate 'subsystem == "local.MaskedNotch"' ;;
esac
