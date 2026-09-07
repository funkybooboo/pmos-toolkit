# Samsung Galaxy Tab A 10.1 2016 (SM-T580) -- gtaxlwifi

First use case of this toolkit. **There is no official postmarketOS port
for this tablet** (the pmaports port is archived with a dead kernel
source) -- but there IS a working community port on Linux 7.1
(`yasstox/gtaxlwifi-port`) with display, touch, Wi-Fi, GPU (Panfrost)
and eMMC boot all working. We install that one.

**Everything operational lives in `INSTALL.md`** (build, flash, verify,
experiments, rollback). `plan.md` is the original 2026-09-07 port plan,
superseded by the found port -- kept for reference.

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