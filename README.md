# pmos-toolkit

Make installing postmarketOS on any device approachable: identify the
device, check its support status in pmaports, back it up, then drive the
right install path.

`pmbootstrap` remains the actual installer; this toolkit routes you to the
correct path for your device and wraps the device-side steps (identify,
backup, flashing). Per-device knowledge lives in `devices/<codename>/`.

All tooling comes from the nix dev shell -- nothing is installed on the
host:

    nix develop
    scripts/identify.sh          # what is plugged in?
    scripts/check-device.sh      # pmaports support tier + recommended path
    scripts/backup.sh            # pull user data off the device

## The honest bit: support is tiered

postmarketOS "support" is not binary, and install difficulty depends
entirely on which pmaports tier the device package sits in:

| pmaports tier   | Meaning                       | Install path                          |
| --------------- | ----------------------------- | ------------------------------------- |
| main, community | well maintained               | turnkey: `pmbootstrap init` -> `install` -> flash |
| testing         | limited functionality         | installable, check the wiki page first |
| downstream      | legacy Android-kernel port    | expect unmaintained                   |
| archived        | unmaintained, often broken    | no turnkey install; porting project   |
| not in pmaports | unsupported                   | from-scratch port                     |

`scripts/check-device.sh` tells you which tier your device is in and
prints the concrete next steps. It builds a local index of every pmaports
device package on first run (~2-4 min, cached in
`~/.cache/pmos-toolkit/devices.json`; rebuild with
`python3 scripts/pmindex.py --refresh`).

## Scripts

- `scripts/identify.sh` -- probe the connected device (adb first, then MTP)
- `scripts/check-device.sh` -- support tier lookup + install path routing
- `scripts/pmindex.py` -- pmaports device index builder/search (stdlib only)
- `scripts/backup.sh` -- backup shared storage (adb pull or MTP mount)
- `scripts/dump-pit.sh` -- Samsung partition table dump (Download mode)
- `scripts/flash-boot.sh` -- Samsung boot.img flash via heimdall (Download mode)

USB flashing tools need root but no udev rules are installed, so the
scripts run them through `sudo -E` from inside the dev shell.

## Device profiles

`devices/<codename>/` holds per-device verdicts, research, and port plans:

- `devices/samsung-gtaxlwifi/` -- Samsung Galaxy Tab A 10.1 2016 (SM-T580): the
  first use case. **Archived tier: no turnkey postmarketOS install.** The
  old port ran a dead Linux 3.18 fork; the viable path is porting onto the
  actively maintained close-to-mainline exynos7870 kernel (same SoC as six
  supported Samsung phones). See its `README.md` and `plan.md`.