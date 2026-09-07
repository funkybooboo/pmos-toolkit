#!/usr/bin/env bash
# Backup shared storage from the connected device.
# Prefers adb (USB debugging on), falls back to an MTP FUSE mount.
# Usage: backup.sh [destination-dir]   (default: backups/<date>)
# NOTE: covers shared storage only; app-private data needs root/TWRP.
set -euo pipefail
dest="${1:-backups/$(date +%Y-%m-%d)}"
mkdir -p "$dest"

if command -v adb >/dev/null 2>&1 && adb devices 2>/dev/null | awk 'NR>1 && $2=="device"{found=1} END{exit !found}'; then
  echo "Backing up /sdcard via adb -> $dest/sdcard ..."
  adb pull -a /sdcard/ "$dest/sdcard/"
else
  mnt=$(mktemp -d)
  echo "No adb device; mounting MTP at $mnt ..."
  simple-mtpfs "$mnt"
  trap 'umount "$mnt" && rmdir "$mnt"' EXIT
  echo "Copying MTP content -> $dest/mtp ..."
  rsync -a --info=progress2 "$mnt/" "$dest/mtp/"
fi

echo "Backup saved under: $dest"