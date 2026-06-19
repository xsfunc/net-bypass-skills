# deploy — canonical tarball install to /opt/zapret2

zapret2 on OpenWrt is **not a system PM package** in the canonical path — it installs from upstream tarball to `/opt/zapret2`, with its own init script. `[evidence: verified]` (openwrt-ops §4: "Tarball install to `/opt/zapret2`, not a system PM package"). The PM axis (apk 25.x / opkg pre-25) governs only the **prerequisite packages** (dependencies) and the firewall-stack variant (fw4 vs fw3) — not the zapret2 install itself. `[evidence: verified]` (openwrt-ops §1 PM-axis definition).

The procedure below synthesises `openwrt-ops §4/§8` (tarball layout + PM rules) with standard OpenWrt init-script conventions. Steps that directly quote openwrt-ops are `verified`; zapret2-specific tarball steps that are widely attested but not in openwrt-ops are `community-observed`.

## Prerequisites (both PM axes)

Before installing zapret2 itself, the router must have the supporting stack. Run preflight per openwrt-ops §1 first (PM-axis detection, install-target free ≥ 1 MB, extroot probe). `[evidence: verified]`

| Component | apk (25.x) | opkg (pre-25) | Evidence |
|-----------|------------|---------------|----------|
| `dnsmasq-full` (nftset support) | `apk add dnsmasq-full` (swap from plain `dnsmasq` per openwrt-ops §8 swap procedure) | `opkg install dnsmasq-full` (opkg may refuse `remove dnsmasq` due to dependents — stop and report, don't `--force-depends`) | verified |
| `nftables-json` (nftset backend) | `apk add nftables-json` | `opkg install nftables-json` | verified |
| `firewall4` (fw4 nftables fw) | default on 25.x | default on 23.05+ | verified |
| `curl`/`wget` (tarball fetch) | `apk add curl` | `opkg install curl` | verified |
| `ca-bundle` (HTTPS fetch) | `apk add ca-bundle` | `opkg install ca-certificates` | verified |

> Heavy runtimes are **not** required for zapret2 (it is C). The constrained-HW ban on Go/Python/Node (openwrt-ops §1) does not apply. `[evidence: verified]`

## Canonical install procedure

### Step 1 — preflight (openwrt-ops §1)

```sh
cat /etc/openwrt_release
command -v apk && apk --version
command -v opkg
df -h / /tmp; free -m
mount | grep -iE 'overlay|/mnt|/dev/sd|/dev/mmcblk'
```

Detect PM axis. Abort if neither/both `apk`/`opkg` present. Abort if projected install-target free < 1 MB. `[evidence: verified]` (openwrt-ops §1 + §0 Non-Negotiables).

### Step 2 — safe-mode snapshot (openwrt-ops §6)

```sh
RB=$(sh /path/to/snapshot.sh)
echo "$RB"
```

The snapshot captures `/etc/config`, `/opt/zapret2/config` (if a previous install exists), `nft list ruleset`, and UCI state to RAM. `[evidence: verified]` (openwrt-ops §6). Arm the revert timer **before** any write step (Step 5+).

### Step 3 — install prerequisites

Install the table above with the detected PM. Use `apk add` or `opkg install` — never mix. `[evidence: verified]` (openwrt-ops §0 + §8).

### Step 4 — fetch & extract the tarball

```sh
# Replace <version> with the latest upstream release tag.
mkdir -p /tmp/zapret2-install
curl -fL -o /tmp/zapret2-install/zapret2.tar.gz \
  https://github.com/bol-van/zapret2/archive/refs/tags/<version>.tar.gz
mkdir -p /opt/zapret2
tar -xzf /tmp/zapret2-install/zapret2.tar.gz -C /opt/zapret2 --strip-components=1
rm -rf /tmp/zapret2-install
```

Layout after extract (canonical): `[evidence: community-observed]` (widely attested upstream layout; not in openwrt-ops)

```
/opt/zapret2/
├── nfqws2              # NFQUEUE engine binary
├── dvtws2              # transparent-proxy engine binary (alternative to nfqws2)
├── init.d/openwrt/zapret2   # init script (deployed in Step 5)
├── config              # shell-file config (the sole non-UCI exception per openwrt-ops §9)
├── lua/                # Lua strategies library (zapret-antidpi.lua, zapret-auto.lua, zapret-lib.lua)
└── bin/                # helper scripts (blockcheck2, etc.)
```

### Step 5 — deploy the init script & enable

```sh
# Deploy the OpenWrt init script
cp /opt/zapret2/init.d/openwrt/zapret2 /etc/init.d/zapret2
chmod +x /etc/init.d/zapret2
# Enable (does NOT start yet)
/etc/init.d/zapret2 enable
```

`[evidence: community-observed]` (init-script deployment pattern; the script path inside the tarball follows upstream OpenWrt packaging conventions).

### Step 6 — arm the rollback timer (openwrt-ops §6)

```sh
( sleep 300 && /tmp/agent-revert.sh "$RB" ) &
echo $! > "$RB/revert.pid"
```

Arm **before** the first start (Step 7) so a broken config or missing binary auto-reverts. `[evidence: verified]` (openwrt-ops §6).

### Step 7 — validate config syntax & start

```sh
# Default config is shipped in the tarball — validate it before first start
sh -n /opt/zapret2/config || { echo "syntax fail"; exit 1; }
/etc/init.d/zapret2 start
ps w | grep -q '[n]fqws2' || { echo "nfqws2 not running"; exit 1; }
logread | tail -20
```

`[evidence: verified]` (openwrt-ops §7 validation: `sh -n` is the pre-apply check for zapret; post-start `ps` confirms the daemon). If `nfqws2` is not running after `start`, **do not** retry — capture the error from `logread`, revert if partial, and report.

### Step 8 — operator confirms & disarm

```sh
touch /tmp/agent_ok
kill "$(cat "$RB/revert.pid")" 2>/dev/null; rm -f /tmp/agent_ok
```

`[evidence: verified]` (openwrt-ops §6 disarm protocol).

### Step 9 — audit

```sh
echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) | install | /opt/zapret2 | OK | tarball <version>, PM=$(command -v apk >/dev/null && echo apk || echo opkg)" >> /tmp/agent-audit.log
```

`[evidence: verified]` (openwrt-ops §10 audit format).

### Step 10 — wire NFQUEUE (next reference file)

After install, nfqws2 will run but **not intercept anything** until nftables/NFQUEUE rules direct traffic to it. See `nfqueue-wiring.md`. `[evidence: verified]` (NFQUEUE is the only delivery path for nfqws2 — `nfq2/nfqws.c` reads exclusively from the NFQUEUE callback).

## Upgrade

zapret2 may be from a custom feed/tarball, not the system PM. `(apk: check apk info zapret2 + /etc/apk/repositories* / opkg: check opkg info zapret2 + /etc/opkg/customfeeds.conf)` before upgrading; follow upstream update procedure. `[evidence: verified]` (openwrt-ops §5 + references/ops-commands.md#upgrades).

The tarball upgrade procedure: `[evidence: community-observed]`

```sh
# 1. Snapshot (openwrt-ops §6)
# 2. Stop the service
/etc/init.d/zapret2 stop
# 3. Back up the current config
cp -a /opt/zapret2/config "$RB/zapret2-config.precopy"
# 4. Extract the new tarball over /opt/zapret2 (preserves config if upstream respects it)
tar -xzf /tmp/zapret2-install/zapret2-new.tar.gz -C /opt/zapret2 --strip-components=1
# 5. Restore the config if overwritten
cp "$RB/zapret2-config.precopy" /opt/zapret2/config
# 6. Validate + arm timer + start (Steps 6-9 above)
```

## Third-party installers (community-observed, NOT canonical)

These are **not governed by this skill**. They are community-maintained wrappers that automate parts of the install. **Audit the script before running it on a live router** (openwrt-ops §11 forbids blind execution of unauthorised scripts); they may hardcode strategies (violating openwrt-ops §11 "no hardcoded zapret strategy") or modify firewall rules outside the safe-mode protocol.

| Installer | What it does | Warnings | Evidence |
|-----------|--------------|----------|----------|
| `zapret4rocket` (`IndeecFOX/zapret4rocket`) | One-liner `curl -O … && sh z4r` that installs zapret + bundled "verified working" strategies. Press Enter to accept defaults. | **Bundles hardcoded strategies** — violates openwrt-ops §11. Auditing the script is mandatory before use. Not the canonical path for this skill. | community-observed |
| `remittor/zapret-openwrt` | opkg package of zapret for OpenWrt (pre-25 oriented). Wiki: `remittor/zapret-openwrt/wiki/Installing-zapret‐openwrt-package`. | opkg-only — does not cover apk 25.x. Side-steps the `/opt/zapret2` tarball layout. Audit package source before install. | community-observed |

> The agent should **stop and ask** before using a third-party installer on a live router — these are community alternatives, not the canonical procedure this skill documents. `[evidence: hypothesis]` (operator-safety policy; no upstream code confirms installer internals).

## Gotchas

- **Never `apk add zapret2` or `opkg install zapret2` from an unknown feed as the canonical install.** The canonical path is the upstream tarball to `/opt/zapret2`. A system-PM `zapret2` package, if present, is likely a third-party wrapper (e.g. `remittor`) — audit its source first. `[evidence: community-observed]`
- **The init script path inside the tarball may vary by release.** Verify `init.d/openwrt/zapret2` exists after extract; if the layout differs, consult upstream release notes before deploying. `[evidence: community-observed]`
- **`/opt` may not exist on a fresh OpenWrt.** `mkdir -p /opt/zapret2` is required (Step 4). On constrained HW, confirm `/opt` lands on the install-target (overlay or extroot), not `/tmp`. `[evidence: verified]` (openwrt-ops §1 install-target rule).
- **`sh -n /opt/zapret2/config` runs before arming the timer** so a syntax error never reaches the apply step (Step 7). `[evidence: verified]` (openwrt-ops Appendix B "Safe-Mode zapret2 Config Edit" makes this explicit).
- **First start with default config will not bypass anything** — the shipped config is a skeleton. NFQUEUE wiring (`nfqueue-wiring.md`) + a `blockcheck2`-derived strategy (`blockcheck.md` + `zapret2-strategies`) are both required before bypass works. `[evidence: verified]` (NFQUEUE delivery + autodetect-never-hardcode).
- **Do not `reboot` to "apply" the install.** `reload`/`restart` only — `reboot` requires literal operator text per openwrt-ops §0. `[evidence: verified]`

## Cross-references

`nfqueue-wiring.md` (mandatory next step — nfqws2 intercepts nothing without NFQUEUE rules); `blockcheck.md` (autodetection after install); `hostlist-ipset-nftset.md` (scoping bypass to specific domains); `theory.md` (why nfqws2 needs NFQUEUE — verdicts model); `zapret2-strategies/reference/preset.md` (config file anatomy); `zapret2-engine-reference/reference/core-flags.md` (preset header globals that live in `/opt/zapret2/config`); `openwrt-ops` §4/§5/§6/§8 (generic install/upgrade/safe-mode/PM rules).

## Source mapping

Upstream code: `nfq2/nfqws.c` (NFQUEUE-only delivery — confirms tarball binary is NFQUEUE-bound). Upstream documentation: openwrt-ops §4 ("Tarball install to `/opt/zapret2`"), §5 (upgrade policy + custom-feed caveat), §6 (safe-mode/snapshot/revert/timer), §8 (PM commands table + install policy + dnsmasq-full swap), §0 Non-Negotiables (no reboot, no hardcoded strategy, UCI-only with `/opt/zapret2/config` exception). Third-party installer references: `IndeecFOX/zapret4rocket`, `remittor/zapret-openwrt` (community repositories — not canonical, audit before use).
