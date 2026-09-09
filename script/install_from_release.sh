#!/bin/bash
set -euo pipefail
umask 077
case "${1:-}" in ""|--verify-only) ;; *) echo "Usage: $0 [--verify-only]" >&2; exit 2 ;; esac
base="https://github.com/yakitori-daisuki/MaskedNotch/releases/download/v0.1.0-preview.1"
name="MaskedNotch-install-unsigned.sh"
temp_root="${TMPDIR:-/tmp}"
work="$(/usr/bin/mktemp -d "${temp_root%/}/masked-notch-download.XXXXXX")"
cleanup() { /bin/rm -rf "$work"; }
trap cleanup EXIT
trap "exit 130" HUP INT TERM
cd "$work"
for file in "$name" "$name.sha256"; do
  /usr/bin/curl --disable --fail --silent --show-error --location \
    --max-redirs 10 --proto "=https" --proto-redir "=https" \
    --connect-timeout 20 --max-time 600 --retry 3 \
    --output "$file" "$base/$file"
done
read -r expected listed extra < "$name.sha256"
[[ -z "${extra:-}" && "$listed" == "$name" && ${#expected} -eq 64 && "$expected" != *[!0-9a-f]* ]] || { echo "Invalid checksum manifest" >&2; exit 1; }
[[ "$(/usr/bin/wc -l < "$name.sha256")" -eq 1 ]] || { echo "Expected one checksum" >&2; exit 1; }
/usr/bin/shasum -a 256 -c "$name.sha256"
if [[ "${1:-}" == --verify-only ]]; then
  /bin/bash "$name" --verify-only
else
  if [[ -d /Applications && -w /Applications ]]; then scope="--system"; else scope="--user"; fi
  /bin/bash "$name" "$scope" --allow-unsigned
fi
