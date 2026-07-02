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

---

## Constrained diagnostics toolbox

`(constrained)` OpenWrt ships BusyBox `ash` with a reduced applet set and no heavy TLS tooling. Before reaching for a diagnostic command, confirm it exists on the device — the BusyBox `nc`, `timeout`, `openssl`, `xxd`, `od` gaps below are all verified on ramips/mt7621. `(capable)` devices may have fuller toolsets; still prefer the zero-install tools here to avoid flash pressure.

### Missing applets (verified, mt7621 / BusyBox 1.37)

| Need | Missing | Reason |
|------|---------|--------|
| command timeout | `timeout` | BusyBox applet not compiled in |
| TCP connect scan | `nc -z -w -v` | BusyBox `nc` is `nc IP PORT` only — no flags |
| TLS handshake probe | `openssl s_client` | `openssl-util` not installed; pulls `libopenssl` ~1.5 MB |
| hex dump | `xxd`, `od` | not present; `hexdump` IS available |

### Zero-install tools (already on the device)

| Tool | Use for | Notes |
|------|---------|-------|
| `curl` (mbedTLS/wolfssl build) | SNI-aware TLS reachability | supports `--connect-to`, `--resolve`, `-k`, `-I`, `--max-time`. Probe build: `curl --version` shows `mbedTLS` or `wolfSSL` |
| `ncat` (nmap) | raw TCP connect | `ncat -z -w N IP port`. Present when `nmap` installed; replaces BusyBox `nc` |
| `uclient-fetch` | URL liveness only | built-in wget replacement. `--timeout=N`/`-T`, `--spider`/`-s`, `--no-check-certificate`. **No SNI control** — resolves via system DNS, sends real SNI but to whatever dnsmasq returns |
| `hexdump` | hex dump | `hexdump -C` substitutes for `xxd`/`od` |

### Timeout wrapper (ash, no `timeout` applet)

```sh
cmd & CPID=$!; (sleep N; kill $CPID 2>/dev/null) & TPID=$!; wait $CPID 2>/dev/null; kill $TPID 2>/dev/null
```

Background the **timer**, not the command. `wait $CPID` returns the instant `cmd` finishes; the trailing `kill $TPID` reaps the still-sleeping timer. The naive `cmd & sleep N; kill $!` blocks for the full `N` even when `cmd` succeeds in 1 s.

### SNI-reachability test (the curl `--connect-to` pattern)

To test a specific IP with the **real SNI** (what DPI actually inspects):

```sh
curl -kI --connect-to "instagram.com:443:57.144.244.34:443" --max-time 8 https://instagram.com
# or, multiple IPs at once:
curl -kI --resolve "instagram.com:443:57.144.244.34,157.240.253.174" --max-time 8 https://instagram.com
```

> **SNI trap.** `curl -k https://$IP` (no `--connect-to`/`--resolve`) sends the bare IP as the TLS SNI. DPI that keys on SNI will not trigger, so a "200 OK" from that test does **not** prove the bypass works for real client traffic. Always bind the real hostname to the target IP via `--connect-to` or `--resolve` so the ClientHello carries the genuine SNI.

### Banned on constrained (footprint or safety)

| Tool / pattern | Why banned |
|----------------|------------|
| `socat`, `openssl-util` | pull `libopenssl` (~1.5 MB); on a 3 MB-free install-target this risks filling flash |
| `netcat-openbsd` | redundant — `ncat` (nmap) already provides `-z -w` |
| `jq` | SKILL.md §2 — use `jsonfilter` |
| `/etc/hosts` edit for diagnostics | violates §6 safe-mode: if the script crashes between `echo >> /etc/hosts` and `sed -i ... /d`, DNS stays poisoned. Use `curl --connect-to`/`--resolve` instead — it needs no hosts-file mutation |
