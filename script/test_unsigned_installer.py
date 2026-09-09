#!/usr/bin/env python3
"""Exercise verification and refusal paths; never install, launch, or alter preferences."""
import base64
import hashlib
from pathlib import Path
import subprocess
import tempfile
import unittest
import re
import shlex

ROOT = Path(__file__).resolve().parent.parent
INSTALLER = ROOT / "dist/MaskedNotch-install-unsigned.sh"


class InstallerTests(unittest.TestCase):
    def test_readme_download_commands_match(self):
        source = (ROOT / "script/install_from_release.sh").read_text().split("\n", 1)[1]
        for filename in ("README.md", "README.ja.md"):
            blocks = re.findall(r"```sh\n(.*?)\n```", (ROOT / filename).read_text(), re.S)
            commands = [block for block in blocks if block.startswith("/bin/bash -c")]
            self.assertEqual(len(commands), 1)
            args = shlex.split(commands[0])
            self.assertEqual(args[:2], ["/bin/bash", "-c"])
            self.assertEqual(args[2], "\n" + source)
            subprocess.run(["/bin/bash", "-n", "-c", args[2]], check=True)

    def run_installer(self, *args, path=INSTALLER):
        # Keep extraction and cleanup entirely under this checkout.
        import os
        env = dict(os.environ, TMPDIR=str(ROOT / "build"))
        return subprocess.run(["/bin/bash", str(path), *args], env=env,
                              capture_output=True, text=True, timeout=30)

    def test_external_checksum(self):
        digest, filename = INSTALLER.with_suffix(".sh.sha256").read_text().split()
        self.assertEqual(filename, INSTALLER.name)
        self.assertEqual(digest, hashlib.sha256(INSTALLER.read_bytes()).hexdigest())

    def test_real_payload_verification(self):
        result = self.run_installer("--verify-only")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Nothing installed", result.stdout)

    def test_missing_consent_refused(self):
        result = self.run_installer("--no-open")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("--allow-unsigned", result.stderr)

    def test_unknown_argument_refused(self):
        result = self.run_installer("--unexpected")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Unknown option", result.stderr)

    def test_help(self):
        result = self.run_installer("--help")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("--verify-only", result.stdout)

    def test_corrupt_payload_refused(self):
        header, payload = INSTALLER.read_bytes().split(b"\n__MASKED_NOTCH_PAYLOAD__\n", 1)
        damaged = bytearray(base64.decodebytes(payload))
        damaged[len(damaged) // 2] ^= 1
        with tempfile.TemporaryDirectory(dir=ROOT / "build") as tmp:
            path = Path(tmp) / "damaged.sh"
            path.write_bytes(header + b"\n__MASKED_NOTCH_PAYLOAD__\n" + base64.encodebytes(damaged))
            result = self.run_installer("--verify-only", path=path)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("checksum mismatch", result.stderr)

    def test_tampered_signature_refused(self):
        # Recompute the payload checksum after changing a signed resource:
        # verification must still reject the altered app's code signature.
        header, payload = INSTALLER.read_bytes().split(b"\n__MASKED_NOTCH_PAYLOAD__\n", 1)
        original = base64.decodebytes(payload)
        with tempfile.TemporaryDirectory(dir=ROOT / "build") as tmp:
            tmp = Path(tmp)
            archive = tmp / "payload.zip"
            archive.write_bytes(original)
            subprocess.run(["ditto", "-x", "-k", str(archive), str(tmp / "unpacked")], check=True)
            app = tmp / "unpacked/MaskedNotch.app"
            with (app / "Contents/Resources/MaskedNotch-LICENSE.txt").open("a") as f:
                f.write("\nAltered resource for verification test\n")
            new_archive = tmp / "changed.zip"
            subprocess.run(["ditto", "-c", "-k", "--keepParent", str(app), str(new_archive)], check=True)
            changed = new_archive.read_bytes()
            header = header.replace(hashlib.sha256(original).hexdigest().encode(),
                                    hashlib.sha256(changed).hexdigest().encode())
            path = tmp / "changed.sh"
            path.write_bytes(header + b"\n__MASKED_NOTCH_PAYLOAD__\n" + base64.encodebytes(changed))
            result = self.run_installer("--verify-only", path=path)
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn("checksum mismatch", result.stderr)
        self.assertIn("sealed resource is missing or invalid", result.stderr)


if __name__ == "__main__":
    unittest.main(verbosity=2)
