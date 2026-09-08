#!/usr/bin/env python3
"""Check packaged translations without launching the app or changing preferences."""
from pathlib import Path
import plistlib
import shutil
import subprocess
import sys

root = Path(__file__).resolve().parent.parent
app = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else root / "build/Variants/Masked Notch Desktop.app"
source = app / "Contents"
stage = root / "build/LocalizationCheck.app/Contents"
stage.mkdir(parents=True, exist_ok=True)
shutil.copytree(source / "Resources", stage / "Resources", dirs_exist_ok=True)
(stage / "MacOS").mkdir(exist_ok=True)
executable = stage / "MacOS/LocalizationCheck"
subprocess.run(["xcrun", "swiftc", "-module-cache-path", str(root / "build/ModuleCache"),
                str(root / "script/check_localizations.swift"), "-o", str(executable)], check=True)
info = plistlib.loads((source / "Info.plist").read_bytes())
info.update(CFBundleExecutable="LocalizationCheck", CFBundleIdentifier="local.MaskedNotch.LocalizationCheck")
(stage / "Info.plist").write_bytes(plistlib.dumps(info))
# Foundation uses the main bundle's supported languages for dependent bundles.
# Match the real app's bundle layout; a bare Swift interpreter selects English.
for preferred, expected in [("(ja-JP)", "ja"), ("(en-GB)", "en"),
                            ("(fr-FR)", "en"), ("(fr-FR, ja-JP)", "ja"),
                            ("(en-US, ja-JP)", "en")]:
    subprocess.run([str(executable), str(app), expected, "-AppleLanguages", preferred], check=True)
