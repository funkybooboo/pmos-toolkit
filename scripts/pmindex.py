#!/usr/bin/env python3
"""Index postmarketOS device packages and report support status.

Subcommands:
  --refresh          rebuild the local index from pmaports (walks every
                     device tier, fetches each APKBUILD; cached at
                     ~/.cache/pmos-toolkit/devices.json)
  --search QUERY     search the index by model string (e.g. "SM-T580") or
                     codename; prints the support tier, kernel, flash
                     method and the recommended install path

Stdlib only. Talks to gitlab.postmarketos.org unauthenticated; be a polite
client (default 8 workers, retry with backoff).
"""

import argparse
import concurrent.futures
import json
import os
import re
import sys
import threading
import time
import urllib.parse
import urllib.request

API = "https://gitlab.postmarketos.org/api/v4/projects/postmarketOS%2Fpmaports"
TIERS = ["main", "community", "testing", "downstream", "archived"]
CACHE = os.path.join(
    os.environ.get("XDG_CACHE_HOME", os.path.expanduser("~/.cache")),
    "pmos-toolkit", "devices.json",
)
UA = "pmos-toolkit/0.1 (postmarketOS install helper)"

_lock = threading.Lock()
_stats = {"done": 0, "errors": 0}


def fetch(url, retries=4):
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    last = None
    for attempt in range(retries):
        try:
            with urllib.request.urlopen(req, timeout=30) as r:
                return r.read().decode()
        except Exception as e:  # noqa: BLE001 - retry any transport error
            last = e
            time.sleep(1.0 * (attempt + 1))
    raise last


def api(endpoint, **params):
    return json.loads(fetch(f"{API}{endpoint}?{urllib.parse.urlencode(params)}"))


def list_device_dirs(tier):
    """List device package directories in one pmaports device tier."""
    dirs, page = [], 1
    while True:
        batch = api("/repository/tree", path=f"device/{tier}", per_page=100,
                    page=page, ref="main")
        if not batch:
            break
        dirs += [e["name"] for e in batch
                 if e["type"] == "tree" and e["name"].startswith("device-")]
        if len(batch) < 100:
            break
        page += 1
    return dirs


def parse_apkbuild(text):
    pkgname = pkgdesc = None
    kernels = set()
    m = re.search(r"^pkgname=(\S+)", text, re.M)
    if m:
        pkgname = m.group(1)
    m = re.search(r'^pkgdesc="?([^"\n]*)"?$', text, re.M)
    if m:
        pkgdesc = m.group(1)
    for k in re.findall(r"\blinux-[a-z0-9][a-z0-9._-]*", text):
        if k != "linux-firmware":
            kernels.add(k)
    return pkgname, pkgdesc, sorted(kernels)


def index_one(tier, dirname):
    path = f"device/{tier}/{dirname}/APKBUILD"
    try:
        text = fetch(
            f"{API}/repository/files/{urllib.parse.quote(path, safe='')}/raw?ref=main"
        )
    except Exception:  # noqa: BLE001 - some dirs have no root APKBUILD
        with _lock:
            _stats["errors"] += 1
        return None
    pkgname, pkgdesc, kernels = parse_apkbuild(text)
    with _lock:
        _stats["done"] += 1
        if _stats["done"] % 50 == 0:
            print(f"  ... {_stats['done']} device packages read", file=sys.stderr)
    return {"tier": tier, "dir": dirname, "pkgname": pkgname,
            "pkgdesc": pkgdesc, "kernels": kernels}


def refresh():
    os.makedirs(os.path.dirname(CACHE), exist_ok=True)
    entries = []
    for tier in TIERS:
        print(f"Indexing device/{tier} ...", file=sys.stderr)
        dirs = list_device_dirs(tier)
        with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:
            results = pool.map(lambda d: index_one(tier, d), dirs)
            entries += [r for r in results if r]
    payload = {"built_at": time.strftime("%Y-%m-%dT%H:%M:%S%z"),
               "pmaports_ref": "main",
               "devices": entries}
    with open(CACHE, "w") as f:
        json.dump(payload, f, indent=1)
    print(f"Indexed {len(entries)} device packages -> {CACHE}", file=sys.stderr)
    if _stats["errors"]:
        print(f"Skipped {_stats['errors']} dirs without a readable APKBUILD",
              file=sys.stderr)


def load_index():
    try:
        with open(CACHE) as f:
            return json.load(f)["devices"]
    except FileNotFoundError:
        sys.exit("No index at %s. Run: python3 scripts/pmindex.py --refresh" % CACHE)


def fetch_deviceinfo(tier, dirname):
    """Return the deviceinfo of a device package (dict of key/values)."""
    path = f"device/{tier}/{dirname}/deviceinfo"
    try:
        text = fetch(
            f"{API}/repository/files/{urllib.parse.quote(path, safe='')}/raw?ref=main"
        )
    except Exception:  # noqa: BLE001 - optional file
        return {}
    out = {}
    for key in ("deviceinfo_name", "deviceinfo_flash_method",
                "deviceinfo_flash_fastboot_kernel", "deviceinfo_arch"):
        m = re.search(rf'^{key}="(.*)"', text, re.M)
        if m:
            out[key] = m.group(1)
    return out


def verdict(tier, pkg):
    codename = pkg["dir"].removeprefix("device-")
    vendor, _, short = codename.partition("-")
    wiki = f"https://wiki.postmarketos.org/w/index.php?search={urllib.parse.quote(codename)}"
    if tier in ("main", "community"):
        return (
            f"VERDICT: supported ({tier} tier) -- turnkey install.\n"
            f"  nix develop, then:\n"
            f"    pmbootstrap init    (vendor {vendor}, codename {short})\n"
            f"    pmbootstrap install\n"
            f"    pmbootstrap flasher flash_rootfs && pmbootstrap flasher flash_kernel\n"
            f"  (flasher uses the device's flash method: {pkg.get('flash_method', 'see deviceinfo')})\n"
            f"  Details: {wiki}"
        )
    if tier == "testing":
        return (
            f"VERDICT: testing tier -- installable with caveats.\n"
            f"  Check what actually works before flashing: {wiki}\n"
            f"  Then: pmbootstrap init (type vendor/codename in), pmbootstrap install."
        )
    if tier == "downstream":
        return (
            f"VERDICT: downstream tier -- legacy Android-kernel port, expect\n"
            f"  unmaintained status. Check {wiki} before relying on it."
        )
    return (
        f"VERDICT: archived -- no turnkey postmarketOS install.\n"
        f"  The port is unmaintained (often a dead kernel) and no longer offered\n"
        f"  by pmbootstrap. This is a porting project now, not an install.\n"
        f"  See {wiki} and any notes under devices/{codename}/ in this repo."
    )


def search(query):
    q = query.upper().strip()
    devices = load_index()
    matches = []
    for d in devices:
        hay = " ".join([d["dir"], d["pkgname"] or "", d["pkgdesc"] or ""]).upper()
        if q in hay:
            matches.append(d)
    if not matches:
        print(f"No pmaports device package matches '{query}'.")
        print("This device is not in postmarketOS at all: a from-scratch port.")
        print("Start here: https://wiki.postmarketos.org/wiki/Porting_to_new_devices")
        return
    print(f"{len(matches)} matching device package(s) in pmaports:\n")
    for d in sorted(matches, key=lambda x: (TIERS.index(x["tier"]), x["dir"])):
        codename = d["dir"].removeprefix("device-")
        info = fetch_deviceinfo(d["tier"], d["dir"])
        d["flash_method"] = info.get("deviceinfo_flash_method", "?")
        print(f"  tier:      {d['tier']}")
        print(f"  codename:  {codename}")
        print(f"  package:   {d['pkgname']} -- {d['pkgdesc']}")
        print(f"  kernel:    {', '.join(d['kernels']) or '?'}")
        print(f"  flash:     {d['flash_method']}")
        print(f"  {verdict(d['tier'], d)}")
        print()


def main():
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument("--refresh", action="store_true", help="rebuild the index")
    p.add_argument("--search", metavar="QUERY",
                   help="search the index by model string or codename")
    args = p.parse_args()

    if args.refresh:
        refresh()
    if args.search:
        search(args.search)
    if not args.refresh and not args.search:
        p.print_help()


if __name__ == "__main__":
    main()