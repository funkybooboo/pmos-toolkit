#!/usr/bin/env bash
# Flash a boot image to a Samsung device via heimdall (Odin protocol).
# Requires: device in Download mode, boot image built by pmbootstrap.
# Usage: flash-boot.sh <boot.img> [PARTITION]   (default partition: BOOT)
set -euo pipefail
img="${1:?usage: flash-boot.sh <boot.img> [PARTITION]}"
part="${2:-BOOT}"
sudo -E heimdall flash --"$part" "$img"