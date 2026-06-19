# ops-commands — PM, validation, and diagnostics reference

Read this file when `SKILL.md` points here: before any package install/upgrade (§Upgrades), before applying firewall/DNS/zapret changes (§Validation), or when diagnosing a broken router (§Diagnostics). Keep `SKILL.md`'s Non-Negotiables (§0) in force throughout.

## Contents

- [Upgrades & Security Allowlist](#upgrades--security-allowlist)
- [Validation matrix](#validation-matrix)
- [nftset probe](#nftset-probe)
- [Diagnostics order](#diagnostics-order)
- [Package Management (apk / opkg)](#package-management-apk--opkg)
- [Install policy](#install-policy)
- [Banned packages](#banned-packages)
- [dnsmasq -> dnsmasq-full swap](#dnsmasq---dnsmasq-full-swap)

---

## Upgrades & Security Allowlist

Allowlist: `dnsmasq`/`dnsmasq-full`, `jsonfilter`, `firewall4`, `nftables`/`nftables-json`, `https-dns-proxy`, `zapret2`, `openssl`/`mbedtls`/`wolfssl`, `ca-bundle`/`ca-certificates`.

- No blanket upgrade via any PM. Targeted only:
```
apk add --upgrade dnsmasq-full jsonfilter firewall4 nftables-json https-dns-proxy ca-bundle   # apk
opkg upgrade dnsmasq-full jsonfilter firewall4 nftables-json https-dns-proxy ca-bundle        # opkg
```
- Every upgrade wrapped in safe-mode (SKILL.md §6): preflight -> snapshot -> arm timer -> apply -> validate -> confirm/disarm.
- `zapret2` may be from a custom feed/tarball, not the system PM. `(apk: check `apk info zapret2` + `/etc/apk/repositories*` / opkg: check `opkg info zapret2` + `/etc/opkg/customfeeds.conf`)` before upgrading; follow upstream update procedure.

---

## Validation matrix

Validate before apply; on failure, do NOT apply, report.

- **nftables** — `nft -c -f <file>` (true pre-apply check)
- **zapret** — `sh -n /opt/zapret2/config`
- **dnsmasq (UCI)** — post-reload: `/etc/init.d/dnsmasq status` + `logread | tail` (see caveat)
- **UCI** — `uci show <config>` after commit

> dnsmasq caveat: `dnsmasq --test` reads the last-generated config, which the init script regenerates only on reload. UCI changes aren't visible to `--test` until reload. The rollback timer is the safety net.

---

## nftset probe

Before relying on nftset:
```sh
dnsmasq --version 2>&1 | tr ' ' '\n' | grep -i nft
apk info nftables-json 2>/dev/null && echo OK || echo MISSING             # apk
opkg list-installed nftables-json 2>/dev/null && echo OK || echo MISSING  # opkg
```
All negative -> ipset fallback (SKILL.md §2) with deviations, or stop and report.

---

## Diagnostics order

When broken, walk this ladder top-down; stop at the first failing layer and fix before descending:

flash/RAM -> services+`logread` -> ping gateway/1.1.1.1/`nslookup` -> `nft list ruleset` -> `dnsmasq --test`+`uci show dhcp` -> zapret config+`ps` -> DoH port check.

---

## Package Management (apk / opkg)

| Task | apk (25.x) | opkg (pre-25) |
|------|------------|---------------|
| Update | `apk update` | `opkg update` |
| Install | `apk add <pkg>` | `opkg install <pkg>` |
| Remove | `apk del <pkg>` | `opkg remove <pkg>` |
| Installed | `apk list -I` / `apk info <pkg>` | `opkg list-installed` / `opkg info <pkg>` |
| Upgradable | `apk list -u` | `opkg list-upgradable` |
| Info/size | `apk info <pkg>` / `apk info -s` | `opkg info <pkg>` |
| Search | `apk search <pkg>` | `opkg list <pkg>` |
| Reinstall | `apk add --force-reinstall <pkg>` | `opkg install --force-reinstall <pkg>` |
| Versions+repos | `apk policy <pkg>` | `opkg info <pkg>` + `/etc/opkg/distfeeds.conf` |

---

## Install policy

preflight -> estimate footprint (`apk info -s` + deps / `opkg info <pkg>`) -> keep >=1 MB free on install-target -> journal to audit log.

---

## Banned packages

Banned always (both axes): `jq`, legacy `iptables`+`kmod-ipt-*`, duplicate DNS servers. Heavy runtimes (`python3`, `node-*`, Go tools `dnscrypt-proxy`/`dnsproxy`/`adguardhome-go`): `(constrained: banned / capable: allowed, C-prefer)`.

---

## dnsmasq -> dnsmasq-full swap

Both `PROVIDES:=dnsmasq`. Procedure: backup dhcp config -> stop -> remove plain -> install -full -> validate -> start.

`(apk: apk del dnsmasq -> apk add dnsmasq-full / opkg: opkg remove dnsmasq -> opkg install dnsmasq-full)`.

opkg caveat: `opkg remove dnsmasq` often refuses due to dependents on the `dnsmasq` virtual (luci, etc.) — don't brute-force `--force-depends`; stop and report the conflict.
