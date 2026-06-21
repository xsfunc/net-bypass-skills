# install zapret2 on OpenWrt

zapret2 on OpenWrt is **not a system package** — it installs from upstream source/tarball to `/opt/zapret2`, with its own init script.

Official zapret2 manual calls `install_easy.sh` the **main installer**. It copies files to `/opt/zapret2`, sets permissions, installs prerequisites, sets up binaries, builds from source if needed, and performs OpenWrt integration.

## Prerequisites 

Before installing zapret2 itself, the router must have the supporting stack.

| Component | apk (25.x) | opkg (pre-25) | Evidence |
|-----------|------------|---------------|----------|
| `dnsmasq-full` (nftset support) | `apk add dnsmasq-full` (swap from plain `dnsmasq` per openwrt-ops §8 swap procedure) | `opkg install dnsmasq-full` (opkg may refuse `remove dnsmasq` due to dependents — stop and report, don't `--force-depends`) | verified |
| `nftables-json` (nftset backend) | `apk add nftables-json` | `opkg install nftables-json` | verified |
| `firewall4` (fw4 nftables fw) | default on 25.x | default on 23.05+ | verified |
| `curl`/`wget` (tarball fetch) | `apk add curl` | `opkg install curl` | verified |
| `ca-bundle` (HTTPS fetch) | `apk add ca-bundle` | `opkg install ca-certificates` | verified |

> Heavy runtimes are **not** required for zapret2 (it is C).

## Canonical install procedure — `install_easy.sh`

Load `openwrt-ops` skill first.

```sh
mkdir -p /tmp/zapret2-install && cd /tmp/zapret2-install
curl -fL -o zapret2.tar.gz https://github.com/bol-van/zapret2/archive/refs/tags/<version>.tar.gz
tar -xzf zapret2.tar.gz --strip-components=1
# Audit the installer before running it on a live router
less install_easy.sh
./install_easy.sh
```

`install_easy.sh` performs the following:

- Copies files to `/opt/zapret2` and sets permissions.
- Installs prerequisites (`install_prereq.sh` behaviour).
- Sets up binaries (`install_bin.sh` behaviour), building from source if no prebuilt binary matches.
- Symlinks the OpenWrt init script: `ln -s /opt/zapret2/init.d/openwrt/zapret2 /etc/init.d/zapret2`.
- Enables autostart: `/etc/init.d/zapret2 enable`.
- Adds hotplug iface handler: `ln -s /opt/zapret2/init.d/openwrt/90-zapret2 /etc/hotplug.d/iface/90-zapret2`.
- (fw3 only) Adds firewall include `firewall.zapret2` via UCI.
- Adds cron job to refresh lists via `/opt/zapret2/ipset/get_config.sh` nightly, random every 2 days.

### Validate post-install

```sh
ls -la /opt/zapret2
sh -n /opt/zapret2/config
ps w | grep -q '[n]fqws2' || /etc/init.d/zapret2 start
ps w | grep '[n]fqws2'
logread | tail -20
```

If `nfqws2` is not running after `start`, **do not** retry blindly — capture the error from `logread`, revert if partial, and report.

### Audit

```sh
echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) | install | /opt/zapret2 | OK | install_easy.sh, PM=$(command -v apk >/dev/null && echo apk || echo opkg)" >> /tmp/agent-audit.log
```

### Wire NFQUEUE (next reference file)

After install, nfqws2 will run but **not intercept anything** until nftables/NFQUEUE rules direct traffic to it. See `nfqueue-wiring.md`.

## Manual tarball fallback

Use this fallback when `install_easy.sh` is unsuitable (custom install path, strict audit, or need to inspect each step). It duplicates what the installer does manually. 

Install the table above with the detected PM. Use `apk add` or `opkg install` — never mix.

```sh
mkdir -p /tmp/zapret2-install && cd /tmp/zapret2-install
curl -fL -o zapret2.tar.gz https://github.com/bol-van/zapret2/archive/refs/tags/<version>.tar.gz
mkdir -p /opt/zapret2
tar -xzf zapret2.tar.gz -C /opt/zapret2 --strip-components=1
```

```sh
# Symlink the OpenWrt init script (do not copy — upstream uses a symlink)
ln -s /opt/zapret2/init.d/openwrt/zapret2 /etc/init.d/zapret2
chmod +x /etc/init.d/zapret2
/etc/init.d/zapret2 enable

# Hotplug iface handler
ln -s /opt/zapret2/init.d/openwrt/90-zapret2 /etc/hotplug.d/iface/90-zapret2

# Cron job for list refresh
( crontab -l 2>/dev/null; echo "0 3 * * * /opt/zapret2/ipset/get_config.sh" ) | crontab -
```

```sh
sh -n /opt/zapret2/config || { echo "syntax fail"; exit 1; }
/etc/init.d/zapret2 start
ps w | grep -q '[n]fqws2' || { echo "nfqws2 not running"; exit 1; }
logread | tail -20
```

## Layout after install

```
/opt/zapret2/
├── nfqws2              # NFQUEUE engine binary
├── dvtws2              # transparent-proxy engine binary (alternative to nfqws2)
├── blockcheck2.sh      # autodetection tool
├── init.d/openwrt/zapret2   # init script (symlinked to /etc/init.d/zapret2)
├── init.d/openwrt/90-zapret2 # hotplug iface handler
├── config              # shell-file config (the sole non-UCI exception per openwrt-ops §9)
├── lua/                # Lua strategies library (zapret-antidpi.lua, zapret-auto.lua, zapret-lib.lua)
├── ipset/              # list-fetching scripts
├── ip2net/             # IP aggregation utility
└── mdig/               # multi-threaded DNS resolver
```

## Upgrade

zapret2 may be from a custom feed/tarball, not the system PM.
For the tarball upgrade procedure:

```sh
# 1. Snapshot
# 2. Stop the service
/etc/init.d/zapret2 stop
# 3. Back up the current config
cp -a /opt/zapret2/config "$RB/zapret2-config.precopy"
# 4. Run the new install_easy.sh (canonical) or extract the new tarball over /opt/zapret2 (fallback)
# 5. Restore the config if overwritten
cp "$RB/zapret2-config.precopy" /opt/zapret2/config
```

## Installer scripts

The upstream tarball ships the following installer/support scripts in its root. `install_easy.sh` is the canonical entry point; the others are supporting scripts it calls internally.

| Script | Purpose | OpenWrt notes |
|--------|---------|---------------|
| `install_easy.sh` | Main installer; dialog mode; auto binaries + prereqs; copies to `/opt/zapret2`; fixes permissions; optionally preserves config/custom/user-lists/autohostlist; builds binaries from source if absent (needs C compiler, make, dev packages — see `docs/compile`) | Canonical path. Audit before running on a live router per openwrt-ops §11. |
| `install_bin.sh` | Auto-find arch-matching binaries; create symlinks in `nfq2/mdig/ip2net` | Tuned for stripped firmwares; called by `install_easy.sh`. |
| `install_prereq.sh` | Install required packages (OpenWrt + most Linux distros) | Uses the detected PM (apk/opkg); called by `install_easy.sh`. |
| `uninstall_easy.sh` | Uninstaller; can't remove autostart on unsupported systems; offers prereq removal only on OpenWrt; doesn't remove install dir | Run manually if needed. |

## Third-party installers (community-observed, NOT canonical)

These are **not governed by this skill**. They are community-maintained wrappers that automate parts of the install. **Audit the script before running it on a live router**; they may hardcode strategies or modify firewall rules outside the safe-mode protocol.

| Installer | What it does | Warnings | Evidence |
|-----------|--------------|----------|----------|
| `zapret4rocket` (`IndeecFOX/zapret4rocket`) | One-liner `curl -O … && sh z4r` that installs zapret + bundled "verified working" strategies. Press Enter to accept defaults. | **Bundles hardcoded strategies**. Auditing the script is mandatory before use. Not the canonical path for this skill. | community-observed |
| `remittor/zapret-openwrt` | opkg package of zapret for OpenWrt (pre-25 oriented). Wiki: `remittor/zapret-openwrt/wiki/Installing-zapret‐openwrt-package`. | opkg-only — does not cover apk 25.x. Side-steps the `/opt/zapret2` tarball layout. Audit package source before install. | community-observed |

> The agent should **stop and ask** before using a third-party installer on a live router — these are community alternatives, not the canonical procedure this skill documents.

## Gotchas

- **Never `apk add zapret2` or `opkg install zapret2` from an unknown feed as the canonical install.** The canonical path is the upstream source + `install_easy.sh`. A system-PM `zapret2` package, if present, is likely a third-party wrapper (e.g. `remittor`) — audit its source first
- **The init script is symlinked, not copied.** The installer symlinks `/opt/zapret2/init.d/openwrt/zapret2` into `/etc/init.d`. Copying works but creates a maintenance burden on upgrade
- **`/opt` may not exist on a fresh OpenWrt.** `mkdir -p /opt/zapret2` is required. On constrained HW, confirm `/opt` lands on the install-target (overlay or extroot), not `/tmp`
- **`sh -n /opt/zapret2/config` runs before start** so a syntax error never reaches the apply step
- **First start with default config will not bypass anything** — the shipped config is a skeleton. NFQUEUE wiring (`nfqueue-wiring.md`) + a `blockcheck2`-derived strategy (`blockcheck.md` + `zapret2-strategies`) are both required before bypass works
- **Do not `reboot` to "apply" the install.** `reload`/`restart` only

## Cross-references

`nfqueue-wiring.md` mandatory next step — nfqws2 intercepts nothing without NFQUEUE rules.
