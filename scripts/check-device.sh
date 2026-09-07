#!/usr/bin/env bash
# Check postmarketOS support for a device and print the recommended path.
# Usage: check-device.sh [MODEL]   (default: auto-identify the connected device)
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"

model="${1:-}"
if [ -z "$model" ]; then
  if ! model=$("$here/identify.sh" --model-only); then
    echo "Could not identify a device. Pass a model: check-device.sh SM-T580" >&2
    exit 1
  fi
fi

echo "Device: $model"
echo

cache="${XDG_CACHE_HOME:-$HOME/.cache}/pmos-toolkit/devices.json"
if [ ! -s "$cache" ]; then
  echo "No local pmaports index; building it now (one-time, ~2-4 min)..."
  python3 "$here/pmindex.py" --refresh
  echo
fi

python3 "$here/pmindex.py" --search "$model"