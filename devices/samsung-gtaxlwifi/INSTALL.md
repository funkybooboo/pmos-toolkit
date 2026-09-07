# postmarketOS on the SM-T580 (gtaxlwifi): install, bring-up, and experiments

Living document for getting postmarketOS fully working on the Samsung Galaxy
Tab A 10.1 2016 (SM-T580, codename `gtaxlwifi`, Exynos 7870) -- and for
keeping notes as we experiment. Update it as things get verified or fixed.

This is NOT the official pmaports port (that one is archived with a dead
kernel). This install uses the working Linux 7.1 port published by
`yasstox` in https://github.com/yasstox/gtaxlwifi-port.

## Current state of this install

Legend: CLAIMED = porter's STATUS.md says it works, UNTESTED = we have not
tried it, VERIFIED = we confirmed it on this exact tablet.

| Subsystem | Porter-claimed | Ours |
| --- | --- | --- |
| Boot into systemd from eMMC | PASS | UNTESTED |
| USB gadget net + SSH | PASS | UNTESTED |
| Internal eMMC (pmOS in SYSTEM partition) | PASS | UNTESTED |
| Wi-Fi (QCA9377, ath10k_sdio, 2.4/5 GHz) | PASS | UNTESTED |
| Display (DECON -> DSIM/MIPI-DSI -> HX8279D) | PASS | UNTESTED |
| Backlight control | PASS | UNTESTED |
| Touchscreen (legacy Samsung STMFTS) | PASS | UNTESTED |
| GPU (Mali-T830 via Panfrost + glamor) | PARTIAL | UNTESTED |
| GPIO keys | PASS | UNTESTED |
| Battery/fuel gauge (SM5703) | PASS | UNTESTED |
| Bluetooth | TODO (not brought up) | -- |
| USB OTG host mode | TODO | -- |
| Audio | not mentioned | UNTESTED |
| Camera | not mentioned | -- |

Known porter caveats: CPU/GPU performance and DVFS tuning still being
refined. BOOT partition limit is 32 MiB (Exynos QCDT boot images).

## Where the port comes from

Meta-repo cloned at `vendor/gtaxlwifi-port/` (gitignored; it is a build
workspace, not our code):

- https://github.com/yasstox/gtaxlwifi-port (meta repo, branch main)
- kernel: https://github.com/yasstox/linux-exynos7870-gtaxlwifi
  branch `port/gtaxlwifi-7.1`, Linux 7.1.0-rc2, 9 commits ahead of
  exynos7870-mainline/7.1; recorded checkpoint f6fc5b0e, packaged commit
  c3db703c
- packaging: https://github.com/yasstox/pmaports-gtaxlwifi branch
  `port/gtaxlwifi-7.1` (device-samsung-gtaxlwifi +
  linux-postmarketos-exynos7870 in device/testing)
- pmbootstrap: pinned submodule (3.11.1)
- upstream SoC effort: https://gitlab.com/exynos7870-mainline (methanal)

Our local pmbootstrap config: `vendor/gtaxlwifi-port/config/pmbootstrap-local.cfg`
(channel systemd-edge, device samsung-gtaxlwifi, UI xfce4,
locale en_US.UTF-8, timezone America/Denver, extra packages: bash, nano,
btop, evtest, libdrm-tests, mesa-demos, mesa-utils, i2c-tools, usbutils,
strace). Device login: user `user`, password `147147` (pmbootstrap
convention, set via .env GTAXL_SSH_PASSWORD).

## Host workspace setup (already done, notes for re-runs)

Everything runs from this repo's nix dev shell (`nix develop`); nothing is
installed on the host OS. Traps hit during setup, kept here because they
will bite again on a fresh clone:

1. Submodules needed: `git submodule update --init src/pmaports
   src/pmbootstrap` (the kernel is fetched by the build as a tarball; the
   `src/linux` submodule is only needed for kernel development or for the
   porter's `build-recovery.sh` helper).
2. pmbootstrap requires the pmaports clone to have a remote pointing at
   the official repo:
   `git -C src/pmaports remote add upstream
   https://gitlab.postmarketos.org/postmarketOS/pmaports.git` then
   `git -C src/pmaports fetch upstream` (it reads channels.cfg from
   upstream/main).
3. A fresh work dir needs a version stamp or pmbootstrap refuses:
   `mkdir -p work/pmbootstrap-work && echo 8 > work/pmbootstrap-work/version`.
4. `gtaxlwifi-local-config` (in the porter's extra_packages) is their
   private, untracked package; removed from our config. If we end up
   needing local tweaks, re-create it as a real package.
5. Build commands MUST run in a real terminal: pmbootstrap calls sudo for
   chroot/loop setup, and a sudo password prompt cannot be answered from a
   non-interactive shell.

## Build (~30-90 min on 22 cores)

Run in a real terminal (it will ask for the sudo password once, then the
pmOS user password for the rootfs; use 147147 to match .env):

```bash
cd ~/Projects/pmos-toolkit && nix develop -c bash -c '
  source vendor/gtaxlwifi-port/scripts/lib/common.sh &&
  pmb build --arch aarch64 --force linux-postmarketos-exynos7870 &&
  pmb build --arch aarch64 --force device-samsung-gtaxlwifi &&
  pmb install --android-recovery-zip --recovery-install-partition=system'
```

Output: `work/pmbootstrap-work/chroot_buildroot_aarch64/var/lib/
postmarketos-android-recovery-installer/pmos-samsung-gtaxlwifi.zip`
(`scripts/flash-recovery.sh` finds this path automatically).
Build log while it runs: `work/pmbootstrap-work/log.txt`.

Alternative (needs the src/linux submodule too): the porter's
`./scripts/build-recovery.sh <label>` does kernel + device + install +
zip in one shot and copies the result to `artifacts/<label>/`.

## Tablet prep (do while the build runs)

1. Backup if desired: `scripts/backup.sh` (adb pull of shared storage;
   userdata is not wiped by the install, but back up anyway).
2. Settings -> About tablet -> tap Build number 7x -> Developer options.
3. Enable **OEM unlocking**. This trips the Knox e-fuse permanently:
   warranty, Samsung Pay, Secure Folder are gone forever. Low stakes for a
   2016 tablet, but it cannot be undone.
4. Enable **USB debugging**.
5. Download mode: power off, then hold Volume Down + Home + Power, confirm
   with Volume Up when the warning screen appears.
6. Boot TWRP: power off, then Volume Up + Home + Power.

## Flash

### One-time: install TWRP (Download mode)

```bash
# image from https://dl.twrp.me/gtaxlwifi/ (twrp-3.7.0_9-0-gtaxlwifi.img)
nix develop -c scripts/dump-pit.sh   # optional: record partition table
sudo -E heimdall flash --RECOVERY twrp-3.7.0_9-0-gtaxlwifi.img
```

### Install pmOS (sideload from TWRP)

1. Boot into TWRP (Volume Up + Home + Power). Allow modifications if asked.
2. In TWRP: Advanced -> ADB Sideload (do not wipe anything).
3. From the repo root:

```bash
cd vendor/gtaxlwifi-port && ./scripts/flash-recovery.sh
```

The script waits for TWRP, switches it to sideload, pushes the recovery
zip, prints TWRP's result line, and reboots into postmarketOS. It needs
sudo for adb (no udev rules on this host; GTAXL_ADB_SUDO=1 in .env).
If pmOS is already running, the same script reboots the tablet into
recovery over SSH first.

What it installs: pmOS boot+rootfs images go into the Android SYSTEM
partition (no repartitioning). Android's OS partition is overwritten;
TWRP on RECOVERY and the USERDATA partition survive.

## First boot + verification checklist

First boot is expected to be slow (initramfs + first-boot systemd
generation). Work through this list and update the table at the top:

- [ ] Boots to the display manager (lightdm) / XFCE session
- [ ] Touch works in the UI
- [ ] USB SSH reachable from host: `cd vendor/gtaxlwifi-port && ./scripts/ssh-device.sh` (user@172.16.42.1, password from .env)
- [ ] `uname -a` shows the 7.1 exynos7870 kernel
- [ ] `timedatectl` shows America/Denver
- [ ] Wi-Fi: `nmcli device wifi list` then `nmcli device wifi connect "<ssid>" password "<pw>"`
- [ ] GPU: `glxinfo -B` shows panfrost renderer (mesa-demos included)
- [ ] Backlight/brightness controls work (UI slider or
      `/sys/class/backlight/*/brightness`)
- [ ] Battery reporting: `upower -d` or /sys/class/power_supply (SM5703)
- [ ] Audio: `aplay -l` (UNKNOWN status -- not in the porter's working
      list; first audio experiment is here)
- [ ] Charging while booted

## Post-install setup

- [ ] Change the default password: `passwd` (and/or install an SSH key,
      then harden sshd)
- [ ] `sudo apk update && sudo apk upgrade` (edge channel, expect churn)
- [ ] Set hostname: `sudo setup-hostname gtaxl` (or nm-hostname-setting)
- [ ] Screensaver/suspend behavior (a tablet wants suspend on lid-less
      inactivity -- experiment)
- [ ] On-screen keyboard for tablet use (XFCE: onboard or squeekboard;
      experiment, note what works)
- [ ] Rotation: accelerometer is not in the porter's working list; manual
      rotation via wlr tools does not apply to XFCE -- xrandr experiment

## Day-2 operations (porter helper scripts)

All from `vendor/gtaxlwifi-port/`, all need a real terminal for sudo:

- `./scripts/build-kernel.sh` -- rebuild kernel package
- `./scripts/build-recovery.sh <label>` -- full build to artifacts/<label>/
- `./scripts/flash-recovery.sh [zip]` -- sideload (auto-finds newest zip)
- `./scripts/ssh-device.sh` -- SSH session
- `./scripts/device-status.sh` -- quick device health dump over SSH
- `./scripts/collect-boot-debug.sh <label>` -- boot logs for debugging
- `./scripts/screen-refresh-test.sh` -- display refresh testing

Kernel development: `src/linux` submodule (branch port/gtaxlwifi-7.1),
`--envkernel` builds from an existing kernel worktree; the porter's docs
warn to verify Image hashes against rootfs /boot/vmlinuz before flashing.

## Experiments backlog

1. Audio -- completely unverified (no mention in the port docs)
2. Bluetooth -- porter TODO
3. USB OTG host mode -- porter TODO
4. GPU performance tuning (Panfrost DVFS)
5. CPU DVFS / governor tuning
6. Sensors (accelerometer/light) -- not brought up
7. Suspend-to-RAM / battery life
8. On-screen keyboard for a usable tablet UI
9. Auto-rotation
10. Upstream: if the port matures, device package could go back to
    pmaports testing via MR (replacing the archived one)

## Recovery / rollback

- To stock Android: Download mode + flash full stock firmware
  (build T580UES5CTL1) via Odin/heimdall (grab from a Samsung firmware
  mirror; flash with heimdall per-partition or Odin in Windows). TWRP
  and pmOS are both gone after a full stock reflash.
- To re-install pmOS: boot TWRP, sideload again.
- TWRP is independent of the SYSTEM partition contents.
- Keep the TWRP image and the recovery zip(s) in artifacts/ for offline
  recovery.

## References

- Port meta-repo: https://github.com/yasstox/gtaxlwifi-port
  (README, STATUS.md, BUILDING.md, INSTALL.md, WIFI.md)
- Kernel fork: https://github.com/yasstox/linux-exynos7870-gtaxlwifi
- Packaging fork: https://github.com/yasstox/pmaports-gtaxlwifi
- Upstream SoC effort: https://gitlab.com/exynos7870-mainline
- TWRP: https://dl.twrp.me/gtaxlwifi/
- Old (dead) official port, history only:
  https://wiki.postmarketos.org/wiki/Samsung_Galaxy_Tab_A_10.1_2016_(samsung-gtaxlwifi)