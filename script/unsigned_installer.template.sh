#!/bin/bash
# Self-contained arm64 package. Source: script/unsigned_installer.template.sh
set -euo pipefail
umask 077
fail() { echo "error: $*" >&2; exit 1; }
scope=user
allow_unsigned=false
launch=true
verify_only=false
for arg in "$@"; do
  case "$arg" in
    --user) scope=user ;;
    --system) scope=system ;;
    --allow-unsigned) allow_unsigned=true ;;
    --no-open) launch=false ;;
    --verify-only) verify_only=true ;;
    --help|-h)
      echo "Usage: bash $0 [--user|--system] --allow-unsigned [--no-open]"
      echo "       bash $0 --verify-only"
      echo "Unnotarized build. --allow-unsigned permits removing this app's quarantine attribute."
      exit 0 ;;
    *) fail "Unknown option: $arg" ;;
  esac
done
[[ "$(uname -s)" == Darwin ]] || fail "macOS is required"
if ! $verify_only; then
  $allow_unsigned || fail "Read the README and pass --allow-unsigned to install this unnotarized build"
  [[ "$(uname -m)" == arm64 ]] || fail "Run from a native Apple Silicon terminal"
  os_version="$(sw_vers -productVersion)"
  [[ "${os_version%%.*}" -ge 26 ]] || fail "macOS 26 or later is required"
  [[ "$EUID" -ne 0 ]] || fail "Run without sudo; use --user if /Applications is not writable"
fi
temp_root="${TMPDIR:-/tmp}"
work="$(mktemp -d "${temp_root%/}/masked-notch-install.XXXXXX")"
stage=""
cleanup() {
  if [[ -n "$stage" ]]; then /bin/rm -rf "$stage"; fi
  /bin/rm -rf "$work"
}
trap cleanup EXIT
trap 'exit 130' HUP INT TERM
payload_line="$(/usr/bin/awk '/^__MASKED_NOTCH_PAYLOAD__$/ {print NR + 1; exit}' "$0")"
[[ -n "$payload_line" ]] || fail "Missing embedded payload"
/usr/bin/tail -n +"$payload_line" "$0" | /usr/bin/base64 -D > "$work/payload.zip"
actual="$(/usr/bin/shasum -a 256 "$work/payload.zip" | /usr/bin/awk '{print $1}')"
[[ "$actual" == '@PAYLOAD_SHA256@' ]] || fail "Embedded payload checksum mismatch"
/usr/bin/ditto -x -k "$work/payload.zip" "$work/unpacked"
app="$work/unpacked/MaskedNotch.app"
[[ -d "$app" && ! -L "$app" ]] || fail "Missing app bundle"
bundle_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app/Contents/Info.plist")"
[[ "$bundle_id" == local.MaskedNotch ]] || fail "Unexpected bundle identifier"
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$app/Contents/Info.plist")" == MaskedNotch ]] || fail "Unexpected executable"
/usr/bin/codesign --verify --deep --strict "$app"
signature="$(/usr/bin/codesign -d --verbose=4 "$app" 2>&1)"
[[ "$signature" == *Signature=adhoc* && "$signature" == *runtime* ]] || fail "Unexpected signing configuration"
if $verify_only; then
  echo "Verified embedded ZIP, bundle identifier, and ad-hoc code signature. Nothing installed."
  exit 0
fi
if [[ "$scope" == system ]]; then
  destination=/Applications
else
  destination="$HOME/Applications"
  /bin/mkdir -p "$destination"
fi
[[ -d "$destination" && -w "$destination" ]] || fail "Destination is not writable; try --user"
target="$destination/Masked Notch.app"
[[ ! -L "$target" ]] || fail "Refusing to replace an app symlink"
if /usr/bin/pgrep -x MaskedNotch >/dev/null; then
  fail "Quit Masked Notch (including experimental variants) before installing"
fi
if [[ -e "$target" ]]; then
  existing_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$target/Contents/Info.plist")"
  [[ "$existing_id" == local.MaskedNotch ]] || fail "Another app occupies the destination"
fi
# Stage on the destination volume before moving an existing installation.
stage="$(mktemp -d "$destination/.masked-notch-stage.XXXXXX")"
/usr/bin/ditto "$app" "$stage/Masked Notch.app"
/bin/chmod -R a+rX "$stage/Masked Notch.app"
# Explicit --allow-unsigned consent applies only to the staged app, never to system policy.
if /usr/bin/xattr -lr "$stage/Masked Notch.app" | /usr/bin/grep -q 'com.apple.quarantine'; then
  /usr/bin/xattr -dr com.apple.quarantine "$stage/Masked Notch.app"
fi
/usr/bin/codesign --verify --deep --strict "$stage/Masked Notch.app"
backup=""
if [[ -e "$target" ]]; then
  backup="$destination/Masked Notch.backup-$(date +%Y%m%d-%H%M%S)-$$.app"
  [[ ! -e "$backup" ]] || fail "Backup path already exists"
  /bin/mv "$target" "$backup"
fi
if ! /bin/mv "$stage/Masked Notch.app" "$target"; then
  if [[ -n "$backup" ]]; then /bin/mv "$backup" "$target"; fi
  fail "Installation failed; previous app restored if present"
fi
echo "Installed: $target"
[[ -z "$backup" ]] || echo "Previous version: $backup"
if $launch; then /usr/bin/open "$target"; fi
exit 0
__MASKED_NOTCH_PAYLOAD__
