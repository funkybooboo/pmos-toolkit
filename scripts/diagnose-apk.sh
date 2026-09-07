#!/usr/bin/env bash
# Diagnose the apk-tools 3.0.8-r0 "failed to write database: No such file or
# directory" failure that kills pmbootstrap install at the local-packages add
# step. Runs the exact failing apk command in 5 variants against the existing
# rootfs. All variants are no-op adds (same packages, same versions), so the
# rootfs state does not change; this is safe to re-run.
#
# Usage (from the repo root):  nix develop -c bash scripts/diagnose-apk.sh
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
source vendor/gtaxlwifi-port/scripts/lib/common.sh

W="$GTAXL_ROOT/work/pmbootstrap-work"
APK="$W/apk.static"
ROOT="$W/chroot_rootfs_samsung-gtaxlwifi"
PKGS="device-samsung-gtaxlwifi linux-postmarketos-exynos7870"

echo "rootfs: $ROOT"
echo "apk:    $($APK --version 2>&1 | head -1)"
echo

run() { local label="$1"; shift; echo "=== $label"; "$@"; echo "exit: $?"; echo; }

# T1: exact failing invocation (has -u), under strace
run "T1: -u, both repos, straced" \
  sudo strace -f -o /tmp/apk-u.strace -e trace=%file "$APK" \
  --no-progress --root "$ROOT" --arch aarch64 \
  --cache-dir "$W/cache_apk_aarch64" \
  --repository "$W/packages/systemd-edge" --repository "$W/packages/edge" \
  add --no-interactive -u $PKGS

# T2: same but without -u
run "T2: no -u, both repos" \
  sudo "$APK" \
  --no-progress --root "$ROOT" --arch aarch64 \
  --cache-dir "$W/cache_apk_aarch64" \
  --repository "$W/packages/systemd-edge" --repository "$W/packages/edge" \
  add --no-interactive $PKGS

# T3: -u but without the repo that has no APKINDEX (systemd-edge)
run "T3: -u, good repo only" \
  sudo "$APK" \
  --no-progress --root "$ROOT" --arch aarch64 \
  --cache-dir "$W/cache_apk_aarch64" \
  --repository "$W/packages/edge" \
  add --no-interactive -u $PKGS

# T4: -u but no --cache-dir (apk falls back to <rootfs>/var/cache/apk)
run "T4: -u, no cache-dir arg" \
  sudo "$APK" \
  --no-progress --root "$ROOT" --arch aarch64 \
  --repository "$W/packages/systemd-edge" --repository "$W/packages/edge" \
  add --no-interactive -u $PKGS

# T5: -u, invoked like the big transactions are (sh -c + progress fifo)
rm -f "$W/tmp/t5fifo"; mkfifo "$W/tmp/t5fifo"
run "T5: -u, sh -c + fifo wrapper" \
  sudo sh -c "exec 3>$W/tmp/t5fifo; $APK --progress-fd 3 --no-progress --root $ROOT --arch aarch64 --cache-dir $W/cache_apk_aarch64 --repository $W/packages/systemd-edge --repository $W/packages/edge add --no-interactive -u $PKGS"
rm -f "$W/tmp/t5fifo"

echo "=== strace ENOENT tail (T1):"
grep ENOENT /tmp/apk-u.strace 2>/dev/null | tail -25
echo
echo "done."