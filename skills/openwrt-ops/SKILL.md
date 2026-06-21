---
name: openwrt-ops
description: OpenWrt router operational safety manual. Use when making any config change on an OpenWrt router. 
---

Binding operational manual for agent with SSH access to an OpenWrt router. If a real device condition conflicts, STOP, report, and await guidance.

Reference targets: OpenWrt 25.x (apk) and pre-25 (opkg), both on **fw4/nftables**, **ash**. Hardware ranges from weak SoC (e.g. ramips/mt7621, 16 MB flash, no extroot) to capable (≥128 MB/extroot, ≥512 MB RAM). Verify profile at runtime.

Scope: DPI bypass (zapret2), DNS (dnsmasq-full, https-dns-proxy), firewall (fw4/nftables), and the network/DHCP plumbing they need. Out of scope (stop and ask): Wi-Fi, firmware (`sysupgrade`/`mtd`), users/SSH keys, LuCI.

**Cross-skill routing:**
- load `/zapret2-router-deploy` for zapret2 install, NFQUEUE wiring, hostlist/ipset/nftset management, and `blockcheck2`
- load `/zapret2-strategies` for desync technique semantics (what to compose after `blockcheck2`)
- load `/zapret2-engine-reference` for engine flag & argument-syntax reference (building a valid `NFQWS2_OPT` line)
- load `/dpi-tspu-strategy-theory` for DPI/TSPU detection theory (why a strategy works)

## Profiles

Two independent axes, auto-detected at engagement start. Read inline markers per the detected axis; an unmarked statement applies to all four corners.

- **PM axis**: `apk` (OpenWrt 25.x) vs `opkg` (pre-25). Detect: `command -v apk; command -v opkg`.
- **HW axis**: `constrained` (~16 MB flash, no extroot, heavy runtimes banned) vs `capable` (≥128 MB flash or extroot, ≥512 MB RAM, heavy runtimes allowed with C-prefer). Detect: install-target free + `free -m` + extroot probe.

Inline markers `(apk: … / opkg: …)` and `(constrained: … / capable: …)` mark branch points; both appear when both axes branch.

---

## Non-Negotiables

- Safe-mode before any firewall/network/DNS/zapret/package change: snapshot to `/tmp/rollback/<ts>/`
- Arm the timer BEFORE applying SSH-risky changes — arming after a lockout is impossible
- Operator confirms, else the timer auto-reverts
- No blanket upgrade via any PM — targeted security allowlist only
- No `reboot` unless the operator literally says "reboot". Use `reload`/`restart`
- UCI only for system settings (`uci set/add_list/del_list/commit`). Never write `/etc/config/*` directly
- Preflight before any install. Abort if projected free space on install-target < 1 MB
- Validate before apply: `nft -c -f` (nftables), `sh -n` (zapret), post-reload status (dnsmasq)
- Out of scope = stop and ask
- No firmware/flash destruction: `sysupgrade`, `mtd write/erase`, `dd … of=/dev/mtd*|sd*`, `mkfs.*`, `rm -rf /` or `/overlay/*`, editing `/etc/openwrt_release` — all PROHIBITED unless operator explicitly approves the specific operation.

Recommended: `sshpass` with env for non-interactive SSH to router. Password via `-p` leaks in `ps`.

---

## 1. Hardware & Preflight

Detect profile at start:

```sh
cat /etc/openwrt_release                            # version → expect apk (25.x) or opkg (pre-25)
command -v apk && apk --version                     # PM axis: apk present?
command -v opkg                                     # PM axis: opkg present? (pre-25)
df -h / /tmp; free -m                               # capacity: install-target free + RAM
mount | grep -iE 'overlay|/mnt|/dev/sd|/dev/mmcblk' # extroot? overlay upperdir on external block dev
```

Profile rules:
- PM axis: exactly one of `apk`/`opkg` expected 
- HW axis: `constrained` if no extroot and install-target is tight (~16 MB class); `capable` if extroot present OR flash ≥128 MB AND RAM ≥512 MB. When uncertain, treat as `constrained`.
- Install-target = overlay mount (`/`) unless extroot is active, in which case it's the extroot mount. Free-space checks always measure the install-target, not `/tmp`.

Prefer `/tmp` (tmpfs/RAM) for transient artifacts on both axes. Heavy runtimes (Go/Python/Node): `(constrained: too large, avoid / capable: allowed, C-prefer)`.

**Done when:** PM axis classified (`apk` or `opkg`), HW axis classified (`constrained` or `capable`), and install-target free space confirmed ≥1 MB for the planned operation. When uncertain on HW axis, default to `constrained` and state the assumption.

---

## 2. Environment Constraints

- Shell: POSIX sh only.
- JSON: `jsonfilter` only. `jq` PROHIBITED. Pattern: `jsonfilter -e '$.field' -e '$.arr[*].key'`.
- Firewall: `fw4`/`nftables`. Prefer `nftset`; `ipset` PROHIBITED as primary.
- ipset fallback: only if nftset confirmed unavailable. Each use logged with `DEVIATION: ipset-fallback` + migration plan to operator. Temporary.

---

## 3. Recency & Freshness Gate → references/ops-commands.md

Read `references/ops-commands.md#recency--freshness-gate` before any security review: update the PM index, compare installed vs available for the §0.4 allowlist, and report a table (package | installed | available | upgrade recommended). Done when every allowlist package has a report row with a yes/no upgrade recommendation.

---

## 4. Approved Stack

- **dnsmasq-full** — Replaces plain `dnsmasq` for nftset support. nftset ON, ipset OFF by default. UCI: `/etc/config/dhcp`.
- **https-dns-proxy** (DoH) — UCI: `/etc/config/https-dns-proxy`. Heavier DoH *clients* (`dnscrypt-proxy`, `dnsproxy`): `(constrained: PROHIBITED / capable: allowed, C-prefer)`. DNS *servers* replacing dnsmasq (`smartdns`, `adguardhome-go`): always stop-and-ask — architectural replacement, out of scope.
- **zapret2** / bol-van/zapret2 (DPI bypass) — `nfqws2` (NFQUEUE) + `dvtws2` (transparent proxy). Config: `/opt/zapret2/config` (shell file). Desync content of `/opt/zapret2/config` (technique taxonomy, preset/profile model, nfqws1->nfqws2 migration, testing ladder): load `$zapret2-strategies`. This manual governs *how* to change zapret2 safely; that pack governs *what* desync strategy to compose after running `blockcheck2`.

---

## 5. Upgrades & Security Allowlist → references/ops-commands.md

Read `references/ops-commands.md#upgrades--security-allowlist` before any PM install/upgrade. Targeted security allowlist only (§0.4 — `dnsmasq-full`, `jsonfilter`, `firewall4`, `nftables-json`, `https-dns-proxy`, `zapret2`, TLS libs, CA bundles); no blanket `apk upgrade`/`opkg upgrade`; every upgrade wrapped in safe-mode (§6); `zapret2` may be a custom feed/tarball — check its source before upgrading.

---

## 6. Safe-Mode & Auto-Rollback

Core safety mechanism. Use for firewall/network/DNS/zapret/package changes touching those. Read-only diagnostics: no. When in doubt, use it — a snapshot costs only RAM; a lockout costs a site visit.

**Snapshot to RAM** — run `scripts/snapshot.sh` on the router. It creates `/tmp/rollback/<ts>/`, captures `uci show` for `network dhcp firewall https-dns-proxy`, copies `/etc/config` and `/opt/zapret2/config`, dumps `nft list ruleset` (audit-only — revert rebuilds nft via fw4, not from this dump), and prints the rollback dir (`$RB`) on stdout for capture:

```sh
RB=$(sh /path/to/snapshot.sh)        # or paste the script body over SSH
echo "$RB"                           # /tmp/rollback/<ts>
```

**Revert script** — `scripts/revert.sh` is the generic `/tmp/agent-revert.sh <RB>` referenced below. Deploy it once per session to `/tmp/agent-revert.sh` on the router (`sh -n` it first), then arm the timer:

```sh
# Arm timer BEFORE applying (for SSH-risky changes)
( sleep 300 && /tmp/agent-revert.sh "$RB" ) &
echo $! > "$RB/revert.pid"
# NOW apply the change (uci commit + reload / nft apply / install)
```

Operator confirms: `touch /tmp/agent_ok`. Agent disarms:
```sh
kill "$(cat "$RB/revert.pid")" 2>/dev/null; rm -f /tmp/agent_ok
```

Window: 5 min default, 10 for slow restarts, never < 2 min.

---

## 7. Validation & Diagnostics → references/ops-commands.md

Read `references/ops-commands.md` (Validation matrix, nftset probe, Diagnostics order) before applying any firewall/DNS/zapret change and when diagnosing a broken router. Key rule: validate before apply (`nft -c -f`, `sh -n /opt/zapret2/config`, post-reload status); on failure, do NOT apply — report. The rollback timer (§6) is the safety net when a check can only run post-apply (dnsmasq UCI caveat).

---

## 8. Package Management → references/ops-commands.md

Read `references/ops-commands.md#package-management-apk--opkg` for the full apk/opkg command table, install policy (keep >=1 MB free on install-target), banned packages (`jq`, legacy iptables, heavy runtimes on constrained HW), and the dnsmasq -> dnsmasq-full swap procedure. Use the detected PM only (§1); never mix `apk` and `opkg`.

---

## 9. Configuration & Restarts

- System settings via UCI: `uci set/add_list/del_list/commit`, then `reload_config` or `/etc/init.d/<svc> reload`. `reload` > `restart` (less disruption).
- `/opt/zapret2/config` (sole non-UCI exception, §0.6): back up, `sh -n` validate, restart via init script.
- Never `kill -9` daemons — use init scripts.

---

## 10. Audit Log

Append to `/tmp/agent-audit.log` (RAM), one line per action:
```
<ISO8601> | <action> | <target> | <result> | [notes/deviations]
```
Log: every PM install/remove/upgrade, uci batch, reload/restart, snapshot + timer arm/disarm, deviation, refused action. No secrets — redact passwords/tokens/keys.

---

## 11. Operator Protocol

- Report plan before non-trivial changes: what, affected services, rollback window.
- On failure: stop, capture error, roll back if partial, report exact command + error. Never guess on hardware — report and ask.

---

## Appendix — Integrated Example → references/safe-mode-walkthrough.md

Read `references/safe-mode-walkthrough.md` for a canonical end-to-end safe-mode walkthrough (dnsmasq nftset add) and the zapret2 config-edit delta, each step with a checkable completion criterion. Corner substitutions (PM/HW axes) live there too.

---

## Scripts

> Both referenced from §6: `scripts/snapshot.sh` (snapshot to RAM, prints rollback dir on stdout) and `scripts/revert.sh` (deploy to `/tmp/agent-revert.sh` on the router, arm via the §6 timer). Both `set -eu`.
