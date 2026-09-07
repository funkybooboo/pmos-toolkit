#!/usr/bin/env bash
# Build the gtaxlwifi kernel + rootfs + recovery zip.
# MUST run in a real terminal: pmbootstrap prompts for the sudo password
# and for the pmOS user password.
# Usage:  nix develop -c bash devices/samsung-gtaxlwifi/build.sh
set -euo pipefail
cd "$(dirname "$0")/../.." || exit 1

[ -d vendor/gtaxlwifi-port/.git ] || {
    echo "ERROR: workspace missing. Run:"
    echo "  nix develop -c bash devices/samsung-gtaxlwifi/setup-workspace.sh"
    exit 1
}

source vendor/gtaxlwifi-port/scripts/lib/common.sh

pmb build --arch aarch64 --force linux-postmarketos-exynos7870
pmb build --arch aarch64 --force device-samsung-gtaxlwifi
pmb install --android-recovery-zip --recovery-install-partition=system

echo
echo "Recovery zip ready at:"
echo "  vendor/gtaxlwifi-port/work/pmbootstrap-work/chroot_buildroot_aarch64/var/lib/postmarketos-android-recovery-installer/pmos-samsung-gtaxlwifi.zip"