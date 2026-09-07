#!/usr/bin/env bash
# Post-flash fixes: install the xorg screen0 conf and the lightdm
# wait-for-panel systemd drop-in onto the device, then restart lightdm.
# Run after the tablet's first boot, with the USB cable connected
# (device at 172.16.42.1). Prompts for the device password
# interactively (nothing stored here).
# Usage:  nix develop -c bash devices/samsung-gtaxlwifi/post-install.sh
set -euo pipefail
cd "$(dirname "$0")/../.." || exit 1

DEV=devices/samsung-gtaxlwifi
HOST="${GTAXL_SSH_HOST:-172.16.42.1}"
USER_="${GTAXL_SSH_USER:-user}"

echo "==> copying device files to the tablet"
scp -o StrictHostKeyChecking=no "$DEV/files/20-exynos-screen.conf" "$USER_@$HOST:/tmp/"
scp -o StrictHostKeyChecking=no "$DEV/files/lightdm-wait-drm.conf" "$USER_@$HOST:/tmp/"

echo "==> installing (device sudo will prompt once)"
ssh -t -o StrictHostKeyChecking=no "$USER_@$HOST" '
    sudo mv /tmp/20-exynos-screen.conf /etc/X11/xorg.conf.d/ &&
    sudo mkdir -p /etc/systemd/system/lightdm.service.d &&
    sudo mv /tmp/lightdm-wait-drm.conf /etc/systemd/system/lightdm.service.d/wait-for-drm.conf &&
    sudo systemctl daemon-reload &&
    sudo systemctl restart lightdm &&
    echo DISPLAY-READY
'

echo
echo "If the above printed DISPLAY-READY, the greeter/XFCE is on the panel."
echo "Both fixes persist on the rootfs: xorg screen0 conf (display) and the"
echo "lightdm drop-in (waits for the DSI panel on cold boot, so every boot"
echo "brings the screen up without manual restarts)."
echo "Final proof: power the tablet fully off, then on -- the greeter must"
echo "appear with no SSH involved."