---
name: openwrt-ops
description: >-
  Binding operational manual for an AI agent with SSH access to an OpenWrt
  router (25.x or pre-25). Governs DPI bypass (zapret2), DNS (dnsmasq-full,
  https-dns-proxy), firewall (fw4/nftables), and the network/DHCP plumbing
  they need, with safe-mode snapshot/rollback, PM/HW profile detection,
  preflight, validation, and audit logging. Invoke $openwrt-ops before
  any router-facing change. Do NOT use for Wi-Fi, firmware/sysupgrade,
  users/SSH keys, or LuCI.
---

# openwrt-ops — OpenWrt router agent operational manual

Binding operational manual for an AI agent with SSH access to an OpenWrt router (25.x or pre-25). "MUST/MUST NOT/SHOULD" per RFC 2119. If a real device condition conflicts, STOP, report, and await guidance.

Reference targets: OpenWrt 25.x (apk) and pre-25/23.05.x (opkg), both on **fw4/nftables**, **ash** (BusyBox), **jsonfilter**. Hardware ranges from weak SoC (e.g. ramips/mt7621, 16 MB flash, no extroot) to capable (≥128 MB/extroot, ≥512 MB RAM). Verify profile at runtime (Profiles, §1).

Scope: DPI bypass (zapret2), DNS (dnsmasq-full, https-dns-proxy), firewall (fw4/nftables), and the network/DHCP plumbing they need. Out of scope (stop and ask): Wi-Fi, firmware (`sysupgrade`/`mtd`), users/SSH keys, LuCI.

## Profiles

Two independent axes, auto-detected at engagement start (§1). Read inline markers per the detected axis; an unmarked statement applies to all four corners.

- **PM axis**: `apk` (OpenWrt 25.x) vs `opkg` (pre-25, e.g. 23.05.x). Detect: `command -v apk; command -v opkg`.
- **HW axis**: `constrained` (~16 MB flash, no extroot, heavy runtimes banned) vs `capable` (≥128 MB flash or extroot, ≥512 MB RAM, heavy runtimes allowed with C-prefer). Detect: install-target free + `free -m` + extroot probe.

Inline markers `(apk: … / opkg: …)` and `(constrained: … / capable: …)` mark branch points; both appear when both axes branch. fw4/nftables is default since 22.03, so the firewall stack is common to all four corners.

---

## 0. Non-Negotiables

1. Safe-mode before any firewall/network/DNS/zapret/package change: snapshot to `/tmp/rollback/<ts>/` (§6) and arm the rollback timer.
2. Arm the timer BEFORE applying SSH-risky changes — arming after a lockout is impossible.
3. Operator confirms via `touch /tmp/agent_ok`, else the timer auto-reverts. Never disarm without that file.
4. No blanket upgrade via any PM — targeted security allowlist only (§5).
5. No `reboot` unless the operator literally says "reboot". Use `reload`/`restart`.
6. UCI only for system settings (`uci set/add_list/del_list/commit`). Never write `/etc/config/*` directly — sole exception: `/opt/zapret2/config`.
7. Preflight (§1) before any install. Abort if projected free space on install-target < 1 MB.
8. ash + jsonfilter only. No bash, no `jq`.
9. Use the detected package manager. If both or neither `apk`/`opkg` present, stop and report. Never mix PMs on one system.
10. Validate before apply: `nft -c -f` (nftables), `sh -n` (zapret), post-reload status (dnsmasq). Apply only on pass.
11. Out of scope = stop and ask. No Wi-Fi, firmware, users, SSH, LuCI.

Recommended: `sshpass` with env for non-interactive SSH to router. Password via `-p` leaks in `ps`.

---

## 1. Hardware & Preflight

Detect profile (both axes) at engagement start and re-verify before any write:

```sh
cat /etc/openwrt_release                            # version → expect apk (25.x) or opkg (pre-25)
command -v apk && apk --version                     # PM axis: apk present?
command -v opkg                                     # PM axis: opkg present? (pre-25)
df -h / /tmp; free -m                               # capacity: install-target free + RAM
mount | grep -iE 'overlay|/mnt|/dev/sd|/dev/mmcblk' # extroot? overlay upperdir on external block dev
```

Profile rules:
- PM axis: exactly one of `apk`/`opkg` expected. Both or neither → stop and report. Never mix PMs.
- HW axis: `constrained` if no extroot and install-target is tight (~16 MB class); `capable` if extroot present OR flash ≥128 MB AND RAM ≥512 MB. When uncertain, treat as `constrained`.
- Install-target = overlay mount (`/`) unless extroot is active, in which case it's the extroot mount. Free-space checks always measure the install-target, not `/tmp`.

Abort if projected install-target free < 1 MB after a planned install. Prefer `/tmp` (tmpfs/RAM) for transient artifacts on both axes. Heavy runtimes (Go/Python/Node): `(constrained: too large, avoid / capable: allowed, C-prefer)`.

---

## 2. Environment Constraints

- Shell: `ash` only. No bash-isms (arrays, `[[ ]]`, `<(...)`, `printf -v`, `coproc`). POSIX sh only.
- JSON: `jsonfilter` only. `jq` PROHIBITED. Pattern: `jsonfilter -e '$.field' -e '$.arr[*].key'`.
- Firewall: `fw4`/`nftables`. Prefer `nftset`; `ipset` PROHIBITED as primary.
- ipset fallback: only if nftset confirmed unavailable (probe in §7). Each use logged with `DEVIATION: ipset-fallback` + migration plan to operator. Temporary.

---

## 3. Recency & Freshness Gate

At engagement start and after any PM update:

1. PM axis already detected (§1). `opkg`-only is normal on pre-25 — do NOT stop. Stop only if neither/both PMs present.
2. Update index: `(apk: apk update / opkg: opkg update)`.
3. Check security allowlist (§5) — compare installed vs available:
```
apk list -u; apk policy <pkg>          # apk: upgradable + installed-vs-available
opkg list-upgradable; opkg info <pkg>  # opkg equivalent
```
4. Report a table: package | installed | available | upgrade recommended (security-driven = yes).

---

## 4. Approved Stack

| Component | Package | Notes |
|-----------|---------|-------|
| DNS/DHCP | `dnsmasq-full` | Replaces plain `dnsmasq` for nftset support. nftset ON, ipset OFF by default. v2.86+ (25.x: 2.91+; 23.05: 2.86 initial, 2.90 in service releases). UCI: `/etc/config/dhcp`. |
| DoH | `https-dns-proxy` | Lightest C DoH client (libcares+libcurl+libev). Depends on jsonfilter. UCI: `/etc/config/https-dns-proxy`. Recommended on all corners. Heavier DoH *clients* (`dnscrypt-proxy`, `dnsproxy`): `(constrained: PROHIBITED / capable: allowed, C-prefer)`. DNS *servers* replacing dnsmasq (`smartdns`, `adguardhome-go`): always stop-and-ask — architectural replacement, out of scope. |
| DPI bypass | `zapret2` (bol-van/zapret2) | `nfqws2` (NFQUEUE) + `dvtws2` (transparent proxy). MUST use autodetection/`blockcheck2` — never hardcode strategy. Config: `/opt/zapret2/config` (shell file, not UCI). Tarball install to `/opt/zapret2`, not a system PM package. |

> Desync content of `/opt/zapret2/config` (technique taxonomy, preset/profile model, nfqws1->nfqws2 migration, testing ladder): load `$zapret2-strategies`. This manual governs *how* to change zapret2 safely; that pack governs *what* desync strategy to compose after running `blockcheck2`.

---

## 5. Upgrades & Security Allowlist → references/ops-commands.md

Read `references/ops-commands.md#upgrades--security-allowlist` before any PM install/upgrade. Targeted security allowlist only (`dnsmasq-full`, `jsonfilter`, `firewall4`, `nftables-json`, `https-dns-proxy`, `zapret2`, TLS libs, CA bundles); no blanket `apk upgrade`/`opkg upgrade`; every upgrade wrapped in safe-mode (§6); `zapret2` may be a custom feed/tarball — check its source before upgrading.

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

- System settings via UCI only: `uci set/add_list/del_list/commit`, then `reload_config` or `/etc/init.d/<svc> reload`. `reload` > `restart` (less disruption).
- Direct `/etc/config/*` writes PROHIBITED. Exception: `/opt/zapret2/config` (shell file) — back up, `sh -n` validate, restart via init script.
- `reboot` only on explicit operator text. Never `kill -9` daemons — use init scripts.

---

## 10. Audit Log

Append to `/tmp/agent-audit.log` (RAM), one line per action:
```
<ISO8601> | <action> | <target> | <result> | [notes/deviations]
```
Log: every PM install/remove/upgrade, uci batch, reload/restart, snapshot + timer arm/disarm, deviation, refused action. No secrets — redact passwords/tokens/keys.

---

## 11. Forbidden Commands

PROHIBITED unless operator explicitly approves the specific operation:

`sysupgrade`, `mtd write/erase`, `dd … of=/dev/mtd*|sd*`, `mkfs.*`, `rm -rf /` or `/overlay/*`, blanket upgrade via any PM (`apk upgrade`/`opkg upgrade` without an allowlist), `reboot`, direct `/etc/config/*` writes (except zapret), mixing `apk` and `opkg` on one system / using the non-detected PM, `jq`, legacy `iptables` as primary, `ipset` as primary, hardcoded zapret strategy, `kill -9` daemons, editing `/etc/openwrt_release`, heavy runtimes (Go/Python/Node) on `constrained` HW.

When uncertain, treat as forbidden → report → ask.

---

## 12. Operator Protocol

- Report plan before non-trivial changes: what, affected services, rollback window, `touch /tmp/agent_ok`.
- Confirmations: safe-mode = `touch /tmp/agent_ok`; reboot = literal "reboot"; out-of-scope = operator names the task.
- On failure: stop, capture error, roll back if partial, report exact command + error. Never guess on hardware — report and ask.

---

## Appendix — Integrated Example: Safe-Mode nftset Change

Add `example.com` to dnsmasq nftset `zapret_v4` (ash-compatible):
```sh
# 1. Preflight
df -h / /tmp; free -m; cat /etc/openwrt_release
# 2. nftset probe
dnsmasq --version 2>&1 | tr ' ' '\n' | grep -i nft
apk info nftables-json 2>/dev/null && echo OK || echo MISSING   # MISSING → §2 ipset fallback or stop
# 3. Snapshot
RB=$(sh scripts/snapshot.sh)     # or inline its body over SSH
# 4. UCI edit
uci add_list dhcp.@dnsmasq[0].nftset='/example.com/4#zapret_v4'; uci commit dhcp
# 5. Arm timer FIRST
( sleep 300 && /tmp/agent-revert.sh "$RB" ) &
echo $! > "$RB/revert.pid"
# 6. Apply
/etc/init.d/dnsmasq reload
# 7. Validate post-reload
/etc/init.d/dnsmasq status && logread | tail -20   # not running → revert + stop
# 8. Operator confirms
touch /tmp/agent_ok
# 9. Disarm
kill "$(cat "$RB/revert.pid")" 2>/dev/null; rm -f /tmp/agent_ok
# 10. Audit
echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) | uci add_list | dhcp.@dnsmasq[0].nftset | OK | example.com -> 4#zapret_v4" >> /tmp/agent-audit.log
```
Timer armed before reload so a DNS breakage still reverts. No `jq` — jsonfilter only if needed.

> The example above is written for the `apk + constrained` corner. Substitutions for the other three corners: (PM) on `opkg`, replace `apk info nftables-json` with `opkg list-installed nftables-json`; the UCI/safe-mode/timer steps are PM-agnostic and unchanged. (HW) `capable` only relaxes the heavy-runtime ban and install-target threshold — neither touched here — so the procedure is identical on capable HW. `opkg`-only is normal on pre-25: do not abort the PM detection when only `opkg` is present.

## Appendix — Integrated Example: Safe-Mode zapret2 Config Edit

Edit `/opt/zapret2/config` (the sole non-UCI exception). Compose desync content from `blockcheck2` + `$zapret2-strategies`; this example shows only the safe-mode wrapping (ash-compatible, PM-agnostic):

```sh
# 1. Preflight
df -h / /tmp; free -m; cat /etc/openwrt_release
# 2. Snapshot (captures /opt/zapret2/config)
RB=$(sh scripts/snapshot.sh)
# 3. Back up the config you are about to edit
cp -a /opt/zapret2/config "$RB/zapret2-config.precopy"
# 4. Edit /opt/zapret2/config (desync from blockcheck2 + $zapret2-strategies)
#    ... apply edits ...
# 5. Validate syntax BEFORE arming
sh -n /opt/zapret2/config || { echo "syntax fail"; exit 1; }
# 6. Arm timer FIRST
( sleep 300 && /tmp/agent-revert.sh "$RB" ) &
echo $! > "$RB/revert.pid"
# 7. Apply: restart via init script
/etc/init.d/zapret2 restart
# 8. Validate post-restart
ps w | grep -q '[n]fqws2' && logread | tail -20   # no nfqws2 process -> revert + stop
# 9. Operator confirms
touch /tmp/agent_ok
# 10. Disarm
kill "$(cat "$RB/revert.pid")" 2>/dev/null; rm -f /tmp/agent_ok
# 11. Audit
echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) | edit | /opt/zapret2/config | OK | desync change" >> /tmp/agent-audit.log
```
Timer armed before restart so a misconfiguration still reverts. `sh -n` runs before arming so a syntax error never reaches the apply step. No `jq`; no direct `/etc/config/*` writes — `/opt/zapret2/config` is the only exception.

---

End. When in doubt: report, ask, default to the safest option that preserves SSH access and flash integrity.

---

## Scripts

- `scripts/snapshot.sh` — safe-mode snapshot to `/tmp/rollback/<ts>/` (§6). Captures UCI, `/etc/config`, `/opt/zapret2/config`, and `nft list ruleset` (audit-only) to RAM. Run on the router; prints the rollback dir on stdout. `set -eu`.
- `scripts/revert.sh` — generic rollback script; deploy to `/tmp/agent-revert.sh` on the router and arm via the §6 timer. Restores configs, then reloads `network` + `firewall` (fw4 rebuilds nft) and restarts dnsmasq/https-dns-proxy/zapret2. `set -eu`.
