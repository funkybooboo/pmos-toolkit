# Research: gtaxlwifi support status (verified 2026-09-07)

Evidence trail for the verdict in README.md. Sources checked directly
unless noted.

## This unit (USB)

- lsusb: `04e8:6860` Samsung, MTP mode, USB serial `520058414db7949f`
- mtp-detect: Model **SM-T580**, Device version T580UES5CTL1
  (Android 8.1), serial R52JA01RP5H, friendly name "Galaxy Tab A (2016)"

## postmarketOS device port

- Wiki: https://wiki.postmarketos.org/wiki/Samsung_Galaxy_Tab_A_10.1_2016_(samsung-gtaxlwifi)
  - Category: **archived**; "no longer appears in pmbootstrap and is
    likely broken"; kernel 3.18.140; mainline: no; FOSS bootloader: no;
    every feature row "Untested"; flashing "Partial".
  - Variants: SM-T580 gtaxlwifi, SM-T585 gtaxllte, SM-P580
    gtanotexlwifi, SM-P585 gtanotexllte.
  - Install notes: TWRP via `heimdall flash --RECOVERY`; full heimdall
    flash gets stuck -> use `pmbootstrap install --android-recovery-zip`
    + TWRP sideload; XFCE4 works (Weston/Plasma-Mobile do not launch);
    `msm-fb-refresher` required.
- pmaports (gitlab.postmarketos.org, ref main):
  - `device/archived/device-samsung-gtaxlwifi` (APKBUILD, deviceinfo,
    kernel-cmdline.conf). deviceinfo: flash method `heimdall-bootimg`,
    BOOT partition, 2048 pagesize.
  - Archived 2026-05-31, commit "samsung-gtaxlwifi: move to archived".
  - `device/archived/linux-samsung-gtaxlwifi`: kernel 3.18.140, source
    `TALUAtGitHub/android_kernel_samsung_exynos7870` -- APKBUILD comment:
    "**Archived: git repo dead and mirrors of that repo do not build**".
    Verified: that GitHub repo returns 404.
- NOT present in device/main, device/community, or device/testing
  (verified via GitLab repository tree API).

## The mainline path (the way forward)

- pmaports `device/testing/linux-postmarketos-exynos7870` 6.15-r6
  (build 2026-07-30, LLVM build): "Close-to-mainline kernel for Samsung
  Exynos 7870 devices", maintainer methanal.
  - Source: kernel.org tarball + patches + devicetrees from
    https://gitlab.com/exynos7870-mainline/mainline-patches
  - devicetrees/: a2corelte, a6lte, j5y17lte, j6lte, j7xelte, on7xelte
    (+ exynos7870.dtsi, pinctrl). **No tablet DTS.**
- Group https://gitlab.com/exynos7870-mainline: linux (branches up to
  7.1; methanal/exynosdrm and methanal/s2mu005 WIP branches), u-boot,
  vendor-firmware (brcm), firmware, per-device repos (on7xelte,
  a2corelte).
- pmaports MR !4980 "samsung-on7xelte: new mainline port" (merged
  2024-03-31) -- later archived with a6lte in the 2026-06-22 "treewide:
  archive unmaintained packages under device/" commit. The device
  packages are recoverable from git history as templates.
- Exynos 7870 phones that work today prove the SoC basics (eMMC, PMIC,
  USB) -- the tablet gap is panel/touch/board-level DTS.

## Fallbacks

- LineageOS: SM-T580 device tree at github.com/retiredtab
  (lineage-18.1, unofficial) -- useful as Android fallback and as
  downstream hardware reference for the port.
- Old downstream kernel is NOT a fallback: source deleted, mirrors
  broken, kernel 3.18 vs modern toolchains.

## Host environment (this machine)

- Arch Linux, nix 2.34.8 (flakes OK); nixpkgs has pmbootstrap 3.11.1,
  heimdall 2.2.2, android-tools 37.0.0, libmtp 1.1.23, simple-mtpfs
  0.4.0 (jmtpfs was removed from nixpkgs as unmaintained).
- pmbootstrap/heimdall not installed on the host OS and they will not
  be: everything comes from this repo's nix dev shell.