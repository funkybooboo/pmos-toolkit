#!/usr/bin/env bash
# Rebuild the gtaxlwifi-port build workspace (vendor/) reproducibly.
# Idempotent: every step checks before acting, safe on an existing workspace.
# Usage (from the toolkit root):  nix develop -c bash devices/samsung-gtaxlwifi/setup-workspace.sh
set -euo pipefail
cd "$(dirname "$0")/../.." || exit 1
DEV=devices/samsung-gtaxlwifi
V=vendor/gtaxlwifi-port

step() { echo "==> $*"; }

step "workspace dir"
mkdir -p vendor

if [ ! -d "$V/.git" ]; then
    step "cloning yasstox/gtaxlwifi-port"
    git clone https://github.com/yasstox/gtaxlwifi-port "$V"
fi

step "submodules (pmaports + pmbootstrap; kernel comes via APKBUILD tarball)"
git -C "$V" submodule update --init src/pmaports src/pmbootstrap

step "pmaports upstream remote (pmbootstrap reads channels.cfg from upstream/main)"
git -C "$V/src/pmaports" remote get-url upstream >/dev/null 2>&1 ||
    git -C "$V/src/pmaports" remote add upstream https://gitlab.postmarketos.org/postmarketOS/pmaports.git
step "pmaports upstream fetch"
git -C "$V/src/pmaports" fetch upstream --quiet

step "work dir + version stamp (a fresh work dir needs 'version' = 8)"
mkdir -p "$V/work/pmbootstrap-work"
[ -f "$V/work/pmbootstrap-work/version" ] || echo 8 > "$V/work/pmbootstrap-work/version"

step "pmbootstrap apk-tools fix (see patches/ for why)"
if git -C "$V/src/pmbootstrap" apply --check "$DEV/patches/pmbootstrap-apk-v3.patch" 2>/dev/null; then
    git -C "$V/src/pmbootstrap" apply "$DEV/patches/pmbootstrap-apk-v3.patch"
    echo "   applied"
else
    echo "   already applied"
fi

step "adb sudo-path fix in the porter helper lib"
if git -C "$V" apply --check "$DEV/patches/common-sh-adb-sudopath.patch" 2>/dev/null; then
    git -C "$V" apply "$DEV/patches/common-sh-adb-sudopath.patch"
    echo "   applied"
else
    echo "   already applied"
fi

step "pmbootstrap config (template has no secrets)"
[ -f "$V/config/pmbootstrap-local.cfg" ] ||
    cp "$DEV/files/pmbootstrap-local.cfg" "$V/config/pmbootstrap-local.cfg"

step "env file"
if [ ! -f "$V/.env" ]; then
    cp "$DEV/files/env.template" "$V/.env"
    echo "   created from template"
fi
if grep -q "CHANGE_ME" "$V/.env" 2>/dev/null; then
    echo "   WARNING: .env still has CHANGE_ME for GTAXL_SSH_PASSWORD --"
    echo "   edit $V/.env and set the device user password"
fi

step "TWRP image (official gtaxlwifi 3.7.0_9-0, sha256-verified)"
mkdir -p "$V/artifacts/twrp"
TWRP="$V/artifacts/twrp/twrp-3.7.0_9-0-gtaxlwifi.img"
TWRP_SHA="407736318e312a17d140bb3093ddbd5d3d0ef73479a8ad5c959161de67b19864"
if [ ! -f "$TWRP" ] || [ "$(sha256sum "$TWRP" | awk '{print $1}')" != "$TWRP_SHA" ]; then
    echo "   downloading (dl.twrp.me needs Referer + browser UA)"
    UA="Mozilla/5.0 (X11; Linux x86_64; rv:130.0) Gecko/20100101 Firefox/130.0"
    curl -sL -A "$UA" -H "Referer: https://dl.twrp.me/gtaxlwifi/" -o "$TWRP" \
        "https://dl.twrp.me/gtaxlwifi/twrp-3.7.0_9-0-gtaxlwifi.img"
fi
if [ "$(sha256sum "$TWRP" | awk '{print $1}')" != "$TWRP_SHA" ]; then
    echo "   ERROR: TWRP sha256 mismatch"
    exit 1
fi
echo "   TWRP sha256 OK"

echo
echo "Workspace ready. Next steps (see devices/samsung-gtaxlwifi/INSTALL.md):"
echo "  1. build:      nix develop -c bash devices/samsung-gtaxlwifi/build.sh"
echo "  2. flash TWRP: nix develop -c bash scripts/flash-twrp.sh   (tablet in Download mode)"
echo "  3. sideload:   vendor/gtaxlwifi-port/scripts/flash-recovery.sh (boot TWRP first)"
echo "  4. display:    nix develop -c bash devices/samsung-gtaxlwifi/post-install.sh"