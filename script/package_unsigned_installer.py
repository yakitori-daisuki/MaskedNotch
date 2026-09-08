#!/usr/bin/env python3
"""Package the freshly built arm64 Release app; no installation or launch."""
import base64
import hashlib
from pathlib import Path
import plistlib
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent.parent
APP = ROOT / "build/ReleaseDerivedData/Build/Products/Release/MaskedNotch.app"
DIST = ROOT / "dist"


def main():
    info = plistlib.loads((APP / "Contents/Info.plist").read_bytes())
    if info.get("CFBundleIdentifier") != "local.MaskedNotch":
        raise SystemExit("Unexpected bundle identifier")
    binary = APP / "Contents/MacOS/MaskedNotch"
    archs = subprocess.check_output(["lipo", "-archs", str(binary)], text=True).strip()
    if archs != "arm64":
        raise SystemExit(f"Expected arm64, got {archs}")
    subprocess.run(["codesign", "--verify", "--deep", "--strict", str(APP)], check=True)
    signature = subprocess.run(["codesign", "-d", "--verbose=4", str(APP)],
                               check=True, capture_output=True, text=True).stderr
    if "Signature=adhoc" not in signature or "runtime" not in signature:
        raise SystemExit("Expected ad-hoc signing with hardened runtime")
    entitlements = subprocess.check_output(["codesign", "-d", "--entitlements", ":-", str(APP)])
    if entitlements.strip() and plistlib.loads(entitlements):
        raise SystemExit("Unexpected Release entitlements")
    for name in ("en.lproj/Localizable.strings", "ja.lproj/Localizable.strings",
                 "LICENSE", "MaskedNotch-LICENSE.txt", "THIRD_PARTY_NOTICES.md"):
        if not (APP / "Contents/Resources" / name).is_file():
            raise SystemExit(f"Missing resource: {name}")
    DIST.mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="installer-", dir=ROOT / "build") as tmp:
        payload = Path(tmp) / "MaskedNotch.zip"
        subprocess.run(["ditto", "-c", "-k", "--sequesterRsrc", "--keepParent",
                        str(APP), str(payload)], check=True)
        data = payload.read_bytes()
        template = (ROOT / "script/unsigned_installer.template.sh").read_text()
        template = template.replace("@PAYLOAD_SHA256@", hashlib.sha256(data).hexdigest())
        output = DIST / "MaskedNotch-install-unsigned.sh"
        output.write_bytes(template.encode() + base64.encodebytes(data))
        output.chmod(0o755)
    digest = hashlib.sha256(output.read_bytes()).hexdigest()
    output.with_suffix(output.suffix + ".sha256").write_text(f"{digest}  {output.name}\n")
    print(f"Version {info['CFBundleShortVersionString']} (build {info['CFBundleVersion']})")
    print(output)
    print(f"SHA-256: {digest}")


if __name__ == "__main__":
    main()
