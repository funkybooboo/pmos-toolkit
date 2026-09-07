#!/usr/bin/env bash
# Post-flash display fix: install the xorg screen0 conf onto the device
# and restart lightdm. Run after the tablet's first boot, with the USB
# cable connected (device at 172.16.42.1).
# Prompts for the device password interactively (nothing stored here).
# Usage:  nix develop -c bash devices/samsung-gtaxlwifi/post-install.sh
set -euo pipefail
cd "$(dirname "$0")/../.." || exit 1

CONF=devices/samsung-gtaxlwifi/files/20-exynos-screen.conf
HOST="${GTAXL_SSH_HOST:-172.16.42.1}"
USER_="${GTAXL_SSH_USER:-user}"

echo "==> copying xorg conf to the tablet"
scp -o StrictHostKeyChecking=no "$CONF" "$USER_@$HOST:/tmp/"

echo "==> installing + restarting lightdm (device sudo will prompt once)"
ssh -t -o StrictHostKeyChecking=no "$USER_@$HOST" \
    "sudo mv /tmp/20-exynos-screen.conf /etc/X11/xorg.conf.d/ && sudo systemctl restart lightdm && echo DONE && cat /sys/class/drm/card2-DSI-1/enabled"

echo
echo "If the above printed 'enabled', the greeter/XFCE should be on the panel."
echo "Why this is needed: see 'REQUIRED post-install display fix' in"
echo "devices/samsung-gtaxlwifi/INSTALL.md."