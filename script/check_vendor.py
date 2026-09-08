#!/usr/bin/env python3
import hashlib
import json
from pathlib import Path

root = Path(__file__).resolve().parent.parent / 'Vendor' / 'SkyLightWindow'
manifest = json.loads((root / 'UPSTREAM.json').read_text())
for name, expected in manifest['sha256'].items():
    actual = hashlib.sha256((root / name).read_bytes()).hexdigest()
    if actual != expected:
        raise SystemExit(f'Vendor mismatch: {name}')
print(f"Verified {len(manifest['sha256'])} pristine files at {manifest['commit']}")
