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
| Install (build + flash + sideload, 2026-09-07) | -- | VERIFIED (RC=0) |
| Boot into systemd from eMMC | PASS | VERIFIED (usb0 up, dhcp, ping 2 ms) |
| USB gadget net + SSH | PASS | VERIFIED (sshd at 172.16.42.1) |
| Internal eMMC (pmOS in SYSTEM partition) | PASS | VERIFIED |
| Wi-Fi (QCA9377, ath10k_sdio, 2.4/5 GHz) | PASS | UNTESTED |
| Display (DECON -> DSIM/MIPI-DSI -> HX8279D) | PASS | VERIFIED (needs xorg conf, see below) |
| Backlight control | PASS | UNTESTED |
| Touchscreen (legacy Samsung STMFTS) | PASS | VERIFIED (on-screen login) |
| GPU (Mali-T830 via Panfrost + glamor) | PARTIAL | UNTESTED |
| GPIO keys | PASS | UNTESTED |
| Battery/fuel gauge (SM5703) | PASS | UNTESTED |
| Bluetooth | TODO (not brought up) | -- |
| USB OTG host mode | TODO | -- |
| Audio | not mentioned | UNTESTED |
| Camera | not mentioned | -- |

Flash-day notes (2026-09-07): sudo needs tool paths resolved BEFORE it
(secure_path hides nix store tools: flash-twrp.sh, patched dump-pit.sh,
patched adb_cmd in scripts/lib/common.sh). Samsung's recovery-from-boot
restores STOCK recovery on every ANDROID boot: after flashing TWRP you
must boot straight into TWRP (hold VolUp+Home+Power from before the
reboot starts) and never let Android boot until pmOS is installed (pmOS
overwrites SYSTEM, killing the restore permanently). We hit this once:
re-flashed, held the combo from reboot, TWRP held, sideload succeeded.

Known porter caveats: CPU/GPU performance and DVFS tuning still being
refined. BOOT partition limit is 32 MiB (Exynos QCDT boot images).

## REINSTALL RUNBOOK (from scratch to booted tablet)

Everything needed lives in this repo. On a fresh checkout:

1. `nix develop -c bash devices/samsung-gtaxlwifi/setup-workspace.sh`
   - clones yasstox/gtaxlwifi-port, inits submodules, adds the upstream
     pmaports remote, stamps the work dir, applies the pmbootstrap and
     adb fixes from patches/, copies the config templates, downloads and
     sha256-verifies TWRP. Idempotent; check its output for the .env
     password warning.
2. Tablet prep: enable Developer options -> OEM unlocking + USB
   debugging (already done once on this tablet; survives flashes).
3. `nix develop -c bash devices/samsung-gtaxlwifi/build.sh`
   - in a REAL terminal: builds kernel + device package + rootfs and
     assembles the recovery zip (~30-90 min first time, cached after).
     Enter the sudo password when asked, and pick the pmOS user password
     (record it in vendor/gtaxlwifi-port/.env).
4. Flash TWRP (Download mode): `nix develop -c bash scripts/flash-twrp.sh`
   - then hold VolUp+Home+Power from BEFORE the reboot starts and boot
     straight into TWRP. NEVER let Android boot first (it restores stock
     recovery; that trap is only dead once pmOS overwrites SYSTEM).
5. Sideload pmOS (TWRP main menu): `cd vendor/gtaxlwifi-port && nix develop ../.. -c ./scripts/flash-recovery.sh`
   - waits for TWRP, sideloads the zip, reboots into pmOS.
6. Display fix (after first boot, USB connected):
   `nix develop -c bash devices/samsung-gtaxlwifi/post-install.sh`
   - installs the xorg screen0 conf and restarts lightdm. Without it the
     screen stays backlit-black (see REQUIRED post-install display fix).
7. Verify: XFCE on panel, touch, `ssh user@172.16.42.1`, wifi via nm-applet.

Boot reliability: the xorg conf and the lightdm wait-for-panel drop-in
persist in /etc on the rootfs, so every boot brings the display up the
same way. The first power-cycle test caught a boot RACE (not rare:
it fired on the very first cold boot): X started before exynos-drm
created /dev/dri/card2, failed with "no screens found", and the panel
stayed backlit-black until `sudo systemctl restart lightdm`. The
lightdm.service.d drop-in (files/lightdm-wait-drm.conf, installed by
post-install.sh) waits for the DSI connector before starting X, which
removes the race. Final proof after installing it: full power off/on
cycle brings up the greeter with no SSH involved.

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
strace). Device login: user `user`, password as chosen at the build
prompt (kept in the gitignored `vendor/gtaxlwifi-port/.env`, template at
`devices/samsung-gtaxlwifi/files/env.template`).
convention, set via .env GTAXL_SSH_PASSWORD).

## Host workspace setup (already done, notes for re-runs)

Everything runs from this repo's nix dev shell (`nix develop`); nothing
is installed on the host OS. Traps hit during setup (kept for context;
setup-workspace.sh handles all of them automatically):

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

## Host-side gotchas hit during the first build (2026-09-07)

`apk-tools 3.0.8-r0` (fresh in Alpine edge when we built) has a
regression: `apk add` against a `--root` chroot with a host `--cache-dir`
intermittently-but-deterministically fails with "System state may be
inconsistent: failed to write database: No such file or directory".
Observed to pass under strace and fail without (see
`scripts/diagnose-apk.sh` in this repo, which reproduces it). Workarounds
shipped in this workspace (all in gitignored `vendor/`):

1. Patched `src/pmbootstrap/pmb/chroot/apk.py` ("pmos-toolkit patch
   2026-09-07 (v3)"): skip the redundant local-package upgrade add
   entirely. The main `apk add` already installs the exact local versions
   (higher versions win repo resolution) and world records them; verified
   in the rootfs db: device-samsung-gtaxlwifi=6-r4,
   linux-postmarketos-exynos7870=7.1.0_rc2-r1. Revisit when apk-tools is
   fixed upstream.
2. `work/pmbootstrap-work/apk.static` is a wrapper running the real
   binary (renamed `apk-real.static`) under a silent strace, as insurance
   for other host apk calls. pmbootstrap re-downloads apk.static only
   when creating chroots, so the wrapper survives re-runs. NOTE: on a
   completely FRESH work dir pmbootstrap re-downloads apk.static (the
   wrapper is not recreated) -- installs still work because the apk.py
   patch (v3) is the real fix; the wrapper was only insurance.

Build result: `pmos-samsung-gtaxlwifi.zip` (525 MiB) at
`work/pmbootstrap-work/chroot_buildroot_aarch64/var/lib/
postmarketos-android-recovery-installer/`.

## Build (~30-90 min on 22 cores)

Run in a real terminal (it will ask for the sudo password once, then the
pmOS user password for the rootfs; record it in
vendor/gtaxlwifi-port/.env):

```bash
nix develop -c bash devices/samsung-gtaxlwifi/build.sh
```

(build.sh = the exact command sequence: pmb build kernel, pmb build
device package, pmb install --android-recovery-zip.)

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

## REQUIRED post-install display fix

The tablet enumerates THREE drm cards: card0 = simpledrm (the inherited
bootloader framebuffer, a stale logo buffer), card1 = panfrost, card2 =
exynos-drm (the real DECON->DSI->panel pipeline). Xorg autoconfig picks
card0 as screen 0 ("Output None-1") and the panel stays disabled:
backlit black screen. Fix: pin screen 0 to card2 with the explicit
ServerLayout conf in this profile (files/20-exynos-screen.conf):

    scp devices/samsung-gtaxlwifi/files/20-exynos-screen.conf user@172.16.42.1:/tmp/
    # on device: sudo mv /tmp/20-exynos-screen.conf /etc/X11/xorg.conf.d/
    # on device: sudo systemctl restart lightdm

Verified 2026-09-07: card2-DSI-1 enabled, Xorg screen 0 on card2, lightdm
greeter and XFCE session on the panel, touch login works. The conf lives
in /etc on the rootfs: after any rootfs reflash it must be reinstalled.
(Eventually this belongs in the device package or a config package; the
porter kept an equivalent in their private gtaxlwifi-local-config.)

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