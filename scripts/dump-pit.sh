#!/usr/bin/env bash
# Dump the Samsung partition table (PIT) with heimdall.
# Requires: device in Download mode (power off, then hold Volume Down +
# Home + Power until the warning screen, confirm with Volume Up).
# Usage: dump-pit.sh [output-file]   (default: pit-<timestamp>.txt)
set -euo pipefail
out="${1:-pit-$(date +%Y%m%d-%H%M%S).txt}"
# resolve heimdall before sudo (sudo secure_path hides nix store tools)
sudo "$(command -v heimdall)" print-pit > "$out"
echo "Partition table written to: $out"