#!/usr/bin/env bash
# Identify the connected Android device: model, firmware, serial.
# Tries adb first (USB debugging enabled), then MTP (file-transfer mode).
# Usage: identify.sh [--model-only]
set -uo pipefail

model_only=0
[ "${1:-}" = "--model-only" ] && model_only=1

model=""
firmware=""
serial=""
android_device=""

# adb path: needs USB debugging enabled on the device
if command -v adb >/dev/null 2>&1; then
  serials=$(adb devices 2>/dev/null | awk 'NR>1 && $2=="device"{print $1}')
  if [ -n "$serials" ]; then
    model=$(adb shell getprop ro.product.model 2>/dev/null | tr -d '\r')
    android_device=$(adb shell getprop ro.product.device 2>/dev/null | tr -d '\r')
    firmware=$(adb shell getprop ro.build.version.release 2>/dev/null | tr -d '\r')
    serial=$(echo "$serials" | head -1)
  fi
fi

# MTP path: works with a stock device in file-transfer mode
if [ -z "$model" ] && command -v mtp-detect >/dev/null 2>&1; then
  out=$(mtp-detect 2>&1)
  model=$(echo "$out" | grep -oP 'Model: \K.*' | head -1 | tr -d '\r')
  firmware=$(echo "$out" | grep -oP 'Device version: \K.*' | head -1 | tr -d '\r')
  serial=$(echo "$out" | grep -oP 'Serial number: \K.*' | head -1 | tr -d '\r')
fi

if [ -z "$model" ]; then
  echo "No device found via adb or MTP." >&2
  echo "Plug the device in (file-transfer mode), or enable USB debugging." >&2
  exit 1
fi

if [ "$model_only" = "1" ]; then
  echo "$model"
  exit 0
fi

echo "Model:            $model"
[ -n "$android_device" ] && echo "Android codename: $android_device"
[ -n "$firmware" ] && echo "Firmware:         $firmware"
[ -n "$serial" ] && echo "Serial:           $serial"