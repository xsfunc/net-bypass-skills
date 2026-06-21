> # Validation and diagnostics reference

## Recency & Freshness Gate

Run before any security review. Update the PM index, compare installed vs available, and report a table.

- Update index: `(apk: apk update / opkg: opkg update)`
- Check security allowlist — compare installed vs available:
```
apk list -u; apk policy <pkg>          # apk: upgradable + installed-vs-available
opkg list-upgradable; opkg info <pkg>  # opkg equivalent
```
- Report a table: package | installed | available | upgrade recommended (security-driven = yes).

Done when: every allowlist package has a row in the report with installed vs available versions and a yes/no upgrade recommendation.

---

## Upgrades & Security Allowlist

Allowlist: `dnsmasq`/`dnsmasq-full`, `fw4`, `nftables`/`nftables-json`, `https-dns-proxy`, `zapret2`, `openssl`/`mbedtls`/`wolfssl`, `ca-bundle`/`ca-certificates`.

- No blanket upgrade via any PM. Targeted only:
```
apk add --upgrade dnsmasq-full jsonfilter firewall4 nftables-json https-dns-proxy ca-bundle   # apk
opkg upgrade dnsmasq-full jsonfilter firewall4 nftables-json https-dns-proxy ca-bundle        # opkg
```

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

## Install policy

preflight -> estimate footprint (`apk info -s` + deps / `opkg info <pkg>`) -> keep >=1 MB free on install-target -> journal to audit log.

---

## dnsmasq -> dnsmasq-full swap

Procedure: backup dhcp config -> stop -> remove plain -> install -full -> validate -> start.

`(apk: apk del dnsmasq -> apk add dnsmasq-full / opkg: opkg remove dnsmasq -> opkg install dnsmasq-full)`.

opkg caveat: `opkg remove dnsmasq` often refuses due to dependents on the `dnsmasq` virtual (luci, etc.) — don't brute-force `--force-depends`; stop and report the conflict.
