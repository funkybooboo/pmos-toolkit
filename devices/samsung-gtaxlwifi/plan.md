# Port plan: gtaxlwifi onto linux-postmarketos-exynos7870

STATUS (2026-09-07): SUPERSEDED. A working port was found the same day
(https://github.com/yasstox/gtaxlwifi-port -- Linux 7.1, display/touch/
WiFi/GPU/eMMC all working). We install that port instead of writing
our own; see INSTALL.md. Kept below for reference if the found port ever
dies and we have to bring the device up ourselves.

Goal: boot postmarketOS on the SM-T580 using the close-to-mainline
exynos7870 kernel, then upstream the port to pmaports.

## Phase 1 -- Talk to the exynos7870-mainline people first

The kernel project is active (branches for 6.15/6.16/6.19/7.1; commits
as recent as 2026-07). Before sinking weeks in:

- maintainer: methanal <kauschluss+methanal@disroot.org>
- group: https://gitlab.com/exynos7870-mainline
  (linux, mainline-patches, u-boot, vendor-firmware, per-device repos)
- ask: is a tablet (gtaxlwifi) DTS planned? what is the state of the
  display work (`methanal/exynosdrm` branch) and the PMIC work
  (`methanal/s2mu005` branch)?
- also worth a ping: postmarketOS Matrix, the archived-port wiki users
  (Shokifrend77 was mainlining it; Troyhanligi reported odd boots)

Rationale: the tablet shares the SoC with six supported phones; if a
tablet DT is already in flight this saves weeks.

## Phase 2 -- Device prep (reversible until the Knox step)

1. `scripts/backup.sh` from the dev shell; note the stock build
   (T580UES5CTL1) in case a reflash of stock is ever needed.
2. Settings -> About tablet -> tap build number 7x -> Developer options:
   enable USB debugging, then enable **OEM unlocking**.
   - WARNING: OEM unlocking trips the Knox e-fuse **permanently**
     (Samsung Pay, Secure Folder, warranty are gone). For a 2016 tablet
     this is low stakes, but it is irreversible.
3. Confirm `adb devices` sees it; record `ro.product.device`
   (cross-check: it should be `gtaxlwifi`).
4. `scripts/dump-pit.sh` -- keep the partition table with the device
   notes.
5. Have TWRP for gtaxlwifi ready (needed for the recovery-zip install
   route; wiki says full heimdall flashing gets stuck).

## Phase 3 -- Build environment

- `nix develop` in this repo.
- Fork pmaports; point pmbootstrap at the fork (pmbootstrap init asks for
  the pmaports checkout / channel; use edge with the local clone).
- Dry-run the loop by building a stock supported device (e.g. an
  exynos7870 phone package from git history) before adding ours.

## Phase 4 -- Reference material

- DTS starting points: `exynos7870-mainline/mainline-patches`
  devicetrees/ (j7xelte is the newest, 2026-01) + exynos7870.dtsi.
- Firmware extraction pattern: `exynos7870-mainline/vendor-firmware`
  (brcm WiFi). SM-T580 blobs must be extracted from the stock firmware
  package or pulled off the device via TWRP dd.
- Downstream hardware reference (panel init, touch, sensors, GPIO):
  LineageOS gtaxlwifi tree (github.com/retiredtab, lineage-18.1).
- Device package template: the mainline on7xelte/a6lte ports in pmaports
  git history (MR !4980, archived 2026-06-22; dig them out of git).

## Phase 5 -- DTS bring-up (the actual work)

1. Copy `exynos7870-j7xelte.dts` -> `exynos7870-gtaxlwifi.dts`; adapt
   memory, eMMC, panel (1920x1200 PLS; likely needs a panel driver --
   the main technical unknown), touch controller, PMIC (s2mu005),
   battery, WiFi (brcm pattern).
2. Kernel config: start from `config-postmarketos-exynos7870.aarch64`.
3. First milestone: boot to the postmarketOS initramfs with USB
   networking (ssh over USB), display can come later.
4. Iterate: build boot.img, `scripts/flash-boot.sh boot.img`, observe,
   repeat. BOOT-partition flashes are recoverable via Download mode.

## Phase 6 -- Device package + install to eMMC

- Add `device/testing/device-samsung-gtaxlwifi` (kernel flavor
  `postmarketos-exynos7870`) to the pmaports fork.
- Install via the TWRP recovery-zip route (wiki-documented):
  `pmbootstrap install --android-recovery-zip`, sideload in TWRP.
- UI: XFCE4 first (proven on this tablet); GPU is Mali-T830 (Midgard) --
  panfrost may light it up once the display pipeline works.

## Phase 7 -- Upstream

- MR the device package + DTS to pmaports (device-samsung-gtaxlwifi,
  testing tier) and the DTS to exynos7870-mainline/mainline-patches.
- Update the wiki device page; move profile notes from this repo to the
  wiki where they belong.

## Risks / honest expectations

- Display pipeline (exynosdrm) is work-in-progress upstream; the tablet
  may sit at "boots + USB net + no display" for a while.
- No fallback: the archived downstream kernel cannot be rebuilt.
- Brick risk from BOOT flashing is low (Download mode recovery); eMMC
  rootfs install is the riskier step -- do it last, after boot works.
- Realistic timeline: weeks to months of hobby-scale kernel work.