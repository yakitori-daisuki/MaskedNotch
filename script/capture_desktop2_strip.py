#!/usr/bin/env python3
"""One diagnostic image of the top strip, gated to a specified displayed desktop (default: Desktop 2).

Does not switch Spaces or change permissions, preferences, wallpaper, or apps.
This is an operational scope check, not a macOS per-Space permission boundary.
"""
import argparse
import datetime
import json
from pathlib import Path
import struct
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parent.parent


def space(wait=False, desktop=2):
    command = ["xcrun", "swift", "-module-cache-path", "build/ModuleCache", "script/inspect_spaces.swift"]
    if wait:
        command.append(f"--wait-for-desktop-{desktop}")
    result = subprocess.run(command, cwd=ROOT, text=True, capture_output=True, timeout=55)
    if result.returncode:
        raise RuntimeError(f"Desktop {desktop} is not ready; no image captured. " + result.stdout.strip() + result.stderr.strip())
    state = json.loads(result.stdout)
    if state.get("currentDesktopNumber") != desktop:
        raise RuntimeError(f"Desktop {desktop} is not displayed; no image captured.")
    return state


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--wait", action="store_true", help="Wait up to 45 seconds for Desktop 2.")
    parser.add_argument("--desktop", type=int, choices=[1, 2], default=2, help="Explicitly select the authorized desktop; defaults to 2.")
    args = parser.parse_args()
    initial = space(wait=args.wait, desktop=args.desktop)
    state = json.loads(subprocess.check_output(
        [str(ROOT / "script/build_and_run.sh"), "--inspect"], cwd=ROOT, text=True, timeout=10))
    displays = state["builtInDisplays"]
    if len(displays) != 1:
        raise RuntimeError("Exactly one built-in display is required; no image captured.")
    display = displays[0]
    if not display["active"] or not display["online"] or display["mirrored"]:
        raise RuntimeError("Unsupported display state; no image captured.")
    bounds = display["bounds"]
    x, y, width, height = bounds["X"], bounds["Y"], bounds["Width"], display["safeTop"]
    if not 0 < height < 100 or width <= 0 or any(float(v) != int(v) for v in (x, y, width, height)):
        raise RuntimeError("Invalid top strip bounds; no image captured.")
    time.sleep(0.2)
    before = space(desktop=args.desktop)
    if before["currentSpaceID"] != initial["currentSpaceID"]:
        raise RuntimeError("Space changed during preparation; no image captured.")
    directory = ROOT / "build/desktop2-review"
    directory.mkdir(parents=True, exist_ok=True)
    stamp = datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%S.%fZ")
    image = directory / (stamp + ".png")
    rect = ",".join(str(int(v)) for v in (x, y, width, height))
    try:
        subprocess.run(["/usr/sbin/screencapture", "-x", "-R" + rect, str(image)], check=True, timeout=10)
        after = space(desktop=args.desktop)
        if after["currentSpaceID"] != before["currentSpaceID"]:
            raise RuntimeError("Space changed during capture; image discarded without inspection.")
        raw = image.read_bytes()
        if raw[:8] != b"\x89PNG\r\n\x1a\n":
            raise RuntimeError("Capture did not produce a PNG.")
        pixels = struct.unpack(">II", raw[16:24])
        expected = (round(width * display["scale"]), round(height * display["scale"]))
        if pixels != expected:
            raise RuntimeError(f"Unexpected capture dimensions {pixels}; expected top strip {expected}.")
    except BaseException:
        image.unlink(missing_ok=True)
        raise
    manifest = {
        "image": str(image), "scope": f"Desktop {args.desktop}, built-in display, top strip only",
        "before": before, "after": after, "rectPoints": [x, y, width, height],
        "imagePixels": pixels, "appState": state,
    }
    image.with_suffix(".json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps({"image": str(image), "manifest": str(image.with_suffix(".json"))}))


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, subprocess.SubprocessError) as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)
