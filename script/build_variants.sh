#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
MASKED_NOTCH_CONFIGURATION=Release ./script/build_and_run.sh --build
python3 script/package_variants.py
