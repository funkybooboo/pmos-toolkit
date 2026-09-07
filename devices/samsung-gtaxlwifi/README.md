# Samsung Galaxy Tab A 10.1 2016 (SM-T580) -- gtaxlwifi

First use case of this toolkit. Verdict up front:

**There is no turnkey postmarketOS install for this tablet.** The
postmarketOS port `device-samsung-gtaxlwifi` was moved to `device/archived/`
in pmaports (2026-05-31) because its downstream kernel source is dead:
the GitHub repo it built from is deleted and mirrors do not build. The
old port ran Linux 3.18.140 (a LineageOS fork) and even the wiki marks
every feature as "Untested".

The viable path is porting the tablet onto the actively maintained
close-to-mainline kernel `linux-postmarketos-exynos7870` (pmaports
testing tier, maintained by methanal, Linux 6.15+). That kernel already
supports six Exynos 7870 *phones*: on7xelte, a6lte, j7xelte, j5y17lte,
j6lte, a2corelte. The SM-T580 shares the SoC, so porting means writing an
`exynos7870-gtaxlwifi.dts` plus a pmaports device package -- real kernel
work, not starting from zero. See `plan.md`.

## Device facts

| Field         | Value                                    |
| ------------- | ---------------------------------------- |
| Model         | SM-T580 (WiFi); SM-T585 gtaxllte (LTE)   |
| S-Pen variant | SM-P580 gtanotexlwifi, SM-P585 gtanotexllte |
| SoC           | Samsung Exynos 7870 (universal7870)      |
| Display       | 1200x1920 PLS LCD                        |
| RAM/storage   | 2/3 GB, 16/32 GB eMMC                    |
| Stock here    | Android 8.1, build T580UES5CTL1          |
| Flashing      | Samsung Download mode + heimdall; no fastboot, no FOSS bootloader |
| This unit     | USB 04e8:6860, MTP serial R52JA01RP5H    |

## Known-good facts from the archived port (wiki)

- TWRP installs via `heimdall flash --RECOVERY twrp.img`; boot TWRP with
  Volume Up + Home + Power.
- Full heimdall flashing gets stuck: the recovery-zip route
  (`pmbootstrap install --android-recovery-zip`, then TWRP
  Advanced -> Sideload) is the documented way to install a rootfs.
- Of the UIs tested back then, XFCE4 worked (Weston and Plasma-Mobile did
  not launch), and `msm-fb-refresher` was required for a UI.

## Decision paths

- **A. Port it** (`plan.md`). Weeks to months; display pipeline is the
  main unknown. Talk to the exynos7870-mainline maintainers first.
- **B. Different hardware.** If the goal is a Linux tablet *now*, pick a
  supported device from the postmarketOS devices page (filter: tablet).
- **C. LineageOS.** Unofficial LineageOS 18.1 exists for the SM-T580 --
  a useful tablet with zero porting, but it is Android, not Linux.