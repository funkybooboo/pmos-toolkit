#!/usr/bin/env bash
# Flash TWRP to the Samsung RECOVERY partition via heimdall (Download mode).
# Verifies the image checksum immediately before writing.
# Usage:  nix develop -c bash scripts/flash-twrp.sh
set -euo pipefail
cd "$(dirname "$0")/.." || exit 1

IMG="vendor/gtaxlwifi-port/artifacts/twrp/twrp-3.7.0_9-0-gtaxlwifi.img"
EXPECTED_SHA="407736318e312a17d140bb3093ddbd5d3d0ef73479a8ad5c959161de67b19864"

# Resolve tools from the devshell before sudo (sudo secure_path hides
# nix store binaries from root).
HEIMDALL="$(command -v heimdall)" || { echo "ERROR: heimdall not on PATH (run inside: nix develop)"; exit 1; }

[ -f "$IMG" ] || { echo "ERROR: TWRP image missing: $IMG"; exit 1; }

actual_sha="$(sha256sum "$IMG" | awk '{print $1}')"
if [ "$actual_sha" != "$EXPECTED_SHA" ]; then
  echo "ERROR: sha256 mismatch! expected $EXPECTED_SHA got $actual_sha"
  exit 1
fi
echo "OK: TWRP image sha256 verified"

echo
echo ">> Waiting for the tablet in Download mode"
echo "   (power off, hold VolDown+Home+Power, confirm with VolUp)..."
sudo "$HEIMDALL" detect --wait

echo
echo ">> Flashing RECOVERY partition (device reboots afterwards)..."
sudo "$HEIMDALL" flash --RECOVERY "$IMG"

echo
echo "FLASH DONE."
echo "NOW: immediately hold VolUp + Home + Power on the tablet and keep"
echo "holding until the TWRP logo appears (boots straight into TWRP)."
echo "In TWRP: swipe to allow modifications. Do NOT wipe anything."