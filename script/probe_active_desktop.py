#!/usr/bin/env python3
"""20-second placement experiment; metadata only, then restore installed app."""
import json
from pathlib import Path
import subprocess
import time

root = Path(__file__).resolve().parent.parent
candidate = root / "build/Variants/Masked Notch Desktop.app"
installed = Path("/Applications/Masked Notch Desktop.app")
if not candidate.is_dir() or not installed.is_dir():
    raise SystemExit("Both candidate and installed Desktop app are required")
evidence = root / "docs/evidence/active-desktop-probe.json"
def inspect(script, *args):
    result = subprocess.run(["xcrun", "swift", "-module-cache-path", "build/ModuleCache",
                             "script/" + script, *args], cwd=root, capture_output=True,
                            text=True, check=True, timeout=10)
    return json.loads(result.stdout)
report = {"before": inspect("inspect_system_state.swift"), "samples": []}
try:
    subprocess.run(["open", "-n", str(candidate), "--args", "--probe-seconds", "20",
                    "--diagnostics", "--probe-active-desktop-band"], check=True)
    start = time.monotonic()
    for _ in range(6):
        time.sleep(2)
        report["samples"].append({"elapsed": time.monotonic() - start,
                                  "spaces": inspect("inspect_spaces.swift", "--bands")})
    remaining = 24 - (time.monotonic() - start)
    if remaining > 0:
        time.sleep(remaining)
    report["afterProbeExit"] = inspect("inspect_system_state.swift")
finally:
    # Normal launch's existing single-instance handling also stops a stuck probe.
    subprocess.run(["open", str(installed), "--args", "--diagnostics"], check=True)
    time.sleep(2)
    report["restored"] = inspect("inspect_system_state.swift")
    evidence.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps({"evidence": str(evidence), "restored": report["restored"]["applications"]}))
