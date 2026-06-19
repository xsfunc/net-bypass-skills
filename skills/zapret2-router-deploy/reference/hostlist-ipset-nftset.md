# hostlist-ipset-nftset — domain & IP filter management, dnsmasq nftset

zapret2's filter flags (`--hostlist*`, `--ipset*`) decide which **domains** and **IPs** a profile applies to. This file covers the management model: the flag families, file formats, the auto-detection variant, the black-list, and the **dnsmasq nftset wiring** on OpenWrt that scopes bypass to specific domains without maintaining a static IP list. For the filter-flag semantics in a profile (`--filter-*` AND `--hostlist`/`--ipset`), see `zapret2-engine-reference/reference/filter.md`.

> `--hostlist`/`--ipset` are **profile-scope** filters (order-independent within the profile, per `zapret2-engine-reference/reference/arg-ordering.md`). They do **not** need to precede `--lua-desync`. `[evidence: verified]`

## `--hostlist*` — domain filters

| Flag | Purpose | Format | Evidence |
|------|---------|--------|----------|
| `--hostlist=<file>` | Include list — bypass applies ONLY to these domains | one domain per line; subdomains auto-included; gzip supported; repeatable | verified |
| `--hostlist-domains=<list>` | Inline include list (no file) | comma-separated | verified |
| `--hostlist-exclude=<file>` | Exclude list — bypass does NOT apply to these | same format as `--hostlist` | verified |
| `--hostlist-exclude-domains=<list>` | Inline exclude list | comma-separated | verified |

`[evidence: verified]` (flag syntax is engine-defined).

### File format

```
youtube.com
google.com
facebook.com
```

`youtube.com` automatically includes `www.youtube.com`, `m.youtube.com`, etc. `[evidence: verified]` (subdomain matching is engine-defined).

### Example

```bash
--hostlist=/opt/zapret2/lists/youtube.txt
--hostlist=/opt/zapret2/lists/list1.txt --hostlist=/opt/zapret2/lists/list2.txt.gz
```

Multiple `--hostlist` flags combine as union. `[evidence: verified]`

## `--hostlist-auto*` — automatic blocked-domain detection

The engine can auto-detect domains that DPI is blocking and add them to a runtime list, so the operator doesn't have to enumerate every blocked domain manually. `[evidence: verified]` (auto-detection mechanism is engine-defined).

| Flag | Purpose | Evidence |
|------|---------|----------|
| `--hostlist-auto=<file>` | File path where auto-detected domains are saved | verified |
| `--hostlist-auto-fail-threshold=<int>` | Failed attempts before adding a domain | verified |
| `--hostlist-auto-fail-time=<int>` | Time window (sec) for the failures to count | verified |
| `--hostlist-auto-retrans-threshold=<int>` | Retransmission count that counts as a failure | verified |
| `--hostlist-auto-debug=<logfile>` | Debug log for the auto-detection | verified |

The auto-list is a **runtime** artifact — the engine writes to it during operation. Don't ship a static `--hostlist-auto` file in the preset; let the engine populate it. `[evidence: community-observed]`

## `--ipset*` — IP filters

| Flag | Purpose | Format | Evidence |
|------|---------|--------|----------|
| `--ipset=<file>` | Include IP list — bypass applies ONLY to these IPs/CIDRs | one IP/CIDR per line; IPv4 + IPv6; gzip; repeatable | verified |
| `--ipset-ip=<list>` | Inline include IP list | comma-separated | verified |
| `--ipset-exclude=<file>` | Exclude IP list | same format as `--ipset` | verified |
| `--ipset-exclude-ip=<list>` | Inline exclude IP list | comma-separated | verified |

`[evidence: verified]` (flag syntax is engine-defined).

### File format

```
192.168.1.0/24
10.0.0.1
2001:db8::/32
```

`[evidence: verified]`

> **Naming clash with kernel ipset.** zapret2's `--ipset` flag is **not** the Linux kernel `ipset` facility — it's the engine's internal IP-list filter, loaded from a plain text file. The kernel-level ipset/nftset is a **separate** OpenWrt facility used by dnsmasq and nftables (see §dnsmasq nftset below). openwrt-ops §2 mandates **nftset over kernel ipset** for OpenWrt. `[evidence: verified]` (openwrt-ops §2).

## Hostlist categories and the black hostlist

A preset's profiles are grouped by **category** — e.g. a YouTube profile, a Discord profile, a Voice profile. Each category is a `--hostlist`/`--ipset` pair attached to its profile. `[evidence: community-observed]` (category model from upstream preset conventions).

### Black hostlist (exclude)

The black hostlist (`--hostlist-exclude`) is for domains that should **never** go through zapret2 even when a broader include rule would catch them. Typical use: a foreign resource that is **not** blocked but would be slowed down by passing through the bypass path. `[evidence: community-observed]`

The black list is **empty by default**; the operator populates it explicitly. Don't ship a pre-filled black list — it's per-deployment. `[evidence: community-observed]`

## dnsmasq nftset — domain-scoped bypass without static IP lists

The robust OpenWrt pattern for "bypass only YouTube and Discord" is **not** to maintain a static `--ipset` of CDN CIDRs (CDNs change, lists rot, mixed ASNs creep in) — it is to let dnsmasq resolve the target domains into an nftset at query time, and have the NFQUEUE rule match that nftset. `[evidence: verified]` (openwrt-ops §2 + §4 dnsmasq-full/nftset; dnsmasq nftset UCI is OpenWrt-defined).

### Prerequisites

- `dnsmasq-full` (not plain `dnsmasq`) — provides nftset support. Swap per openwrt-ops §8.
- `nftables-json` — nftset backend. Probe: `dnsmasq --version 2>&1 | tr ' ' '\n' | grep -i nft` + `apk info nftables-json` / `opkg list-installed nftables-json`. `[evidence: verified]` (openwrt-ops §7 nftset probe).

### UCI configuration

```sh
# Snapshot first (openwrt-ops §6)
RB=$(sh /path/to/snapshot.sh)

# Add a domain to the nftset 'zapret_v4' (IPv4) — dnsmasq resolves and inserts
uci add_list dhcp.@dnsmasq[0].nftset='/youtube.com/4#zapret_v4'
uci add_list dhcp.@dnsmasq[0].nftset='/discord.com/4#zapret_v4'
# IPv6 variant
uci add_list dhcp.@dnsmasq[0].nftset='/youtube.com/6#zapret_v6'
uci commit dhcp

# Arm timer (openwrt-ops §6)
( sleep 300 && /tmp/agent-revert.sh "$RB" ) &
echo $! > "$RB/revert.pid"

# Apply
/etc/init.d/dnsmasq reload

# Validate post-reload (openwrt-ops §7 dnsmasq caveat: status + logread, --test sees only post-reload config)
/etc/init.d/dnsmasq status && logread | tail -20

# Operator confirms + disarm + audit
touch /tmp/agent_ok
kill "$(cat "$RB/revert.pid")" 2>/dev/null; rm -f /tmp/agent_ok
echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) | uci add_list | dhcp.@dnsmasq[0].nftset | OK | youtube.com discord.com -> 4#zapret_v4 6#zapret_v6" >> /tmp/agent-audit.log
```

`[evidence: verified]` (UCI path + nftset syntax `/<domain>/<family>#<setname>` are OpenWrt-defined; safe-mode per openwrt-ops §6/§7/§10 — this is the openwrt-ops Appendix A example).

### nftset declaration

The nftset `zapret_v4` / `zapret_v6` must exist in the nftables ruleset before dnsmasq tries to insert into it. Declare it in the same `/etc/nftables.d/10-zapret2.nft` include as the NFQUEUE rule: `[evidence: verified]` (nftables set declaration semantics)

```nft
table inet zapret2 {
    set zapret_v4 {
        type ipv4_addr
        flags interval
        timeout 86400    # 24h — entries expire if dnsmasq doesn't refresh
    }
    set zapret_v6 {
        type ipv6_addr
        flags interval
        timeout 86400
    }
    chain divert {
        type filter hook prerouting priority mangle; policy accept;
        ip daddr @zapret_v4 tcp dport { 443, 80 } counter queue num 200
        ip6 daddr @zapret_v6 tcp dport { 443, 80 } counter queue num 200
    }
}
```

`[evidence: verified]` (nftables set + queue syntax).

### Why this beats static `--ipset`

- **CDN churn**: YouTube/Discord serve from rotating CDN IPs. A static list rots in days; dnsmasq re-resolves on each TTL expiry.
- **Mixed ASNs**: a hand-collected IP list (e.g. `ipset-discord`) often mixes Discord CDN with Google/Cloudflare ranges — see §below.
- **Dual-stack**: dnsmasq inserts both A and AAAA records; the static list has to track both manually.

`[evidence: community-observed]` (the pattern is widely attested in upstream zapret2 + OpenWrt community); `[evidence: hypothesis]` (effectiveness delta is reasoning, not measured).

## `ipset-discord` raw CIDR — needs curation, never load as-is

A raw Discord CDN CIDR list circulates in the community. It is **not safe to load as a ready-made `--ipset` or nftset rule**:

- **Duplicates**: the list contains repeated ranges (e.g. `35.207.0.0/16`–`35.214.0.0/16` appears twice in known copies).
- **Mixed ASNs**: entries span Discord CDN, Google (`172.217.x`, `142.250.x`, `64.233.x`, `74.125.x`, `108.177.x`, `142.251.x`, `209.85.x`, `173.194.x`), Cloudflare (`104.17.x`–`104.25.x`, `162.159.x`, `172.65.x`–`172.67.x`, `188.114.x`), Amazon (`18.165.x`, `23.227.x`, `34.0.x`–`34.128.x`, `35.186.x`–`35.219.x`). Treating it as "Discord" mis-scope the bypass to a broad set of unrelated CDNs.
- **No IPv6**: the list is IPv4-only; Discord serves over IPv6 from many networks.

`[evidence: community-observed]` (list contents attested in community copies); `[evidence: hypothesis]` (impact of loading as-is is reasoning).

**Use it only as a curation starting point**: deduplicate, verify ASN ownership against a current source (`whois -h whois.radb.net <ip>` or equivalent), split into per-ASN sets, and prefer the **dnsmasq nftset** approach (which sidesteps the IP-list problem entirely by resolving `discord.com` and its subdomains at runtime). `[evidence: community-observed]`

> Loading a raw community CIDR list as `--ipset` on a live router violates openwrt-ops §11's "no hardcoded zapret strategy" spirit (a mis-scoped IP list is as bad as a wrong strategy) — **stop and ask** before applying. `[evidence: hypothesis]` (operator-safety policy).

## Gotchas

- **`--hostlist` subdomain matching is automatic** — listing `youtube.com` covers all subdomains. Don't list `www.youtube.com` separately; it's redundant. `[evidence: verified]`
- **`--hostlist-auto` writes to the file at runtime.** Don't put the auto file on read-only storage (e.g. squashfs without overlay) — use the overlay or `/tmp`. `[evidence: community-observed]`
- **nftset timeout must be longer than DNS TTL** or entries expire before dnsmasq refreshes. 86400 sec (24h) is a safe default; dnsmasq re-inserts on each query response. `[evidence: community-observed]`
- **`--ipset` (zapret2 flag) ≠ kernel ipset** (OpenWrt facility). The first is an engine-internal text-file IP filter; the second is a kernel data structure openwrt-ops §2 deprecates in favour of nftset. Don't confuse them. `[evidence: verified]`
- **The dnsmasq nftset UCI key is `nftset`**, not `ipset`. Using `ipset` would use the deprecated kernel ipset path. `[evidence: verified]` (openwrt-ops §2 + dnsmasq-full UCI).
- **Test nftset population after `dnsmasq reload`**: `nft list set inet zapret2 zapret_v4` should show resolved IPs after a query. Empty set → dnsmasq didn't insert (check `logread` for dnsmasq nftset errors). `[evidence: verified]` (nftables set-list command is standard; dnsmasq logs insertion errors).
- **Don't mix `--hostlist` (domain) and `--ipset` (IP) when they conflict.** If a domain hostlist includes `youtube.com` but the ipset excludes `142.250.0.0/16`, a YouTube connection from that range is excluded — confusing. Pick one scoping axis per profile. `[evidence: hypothesis]` (interaction is logical, not code-confirmed here).

## Cross-references

`zapret2-engine-reference/reference/filter.md` (profile-scope filter AND semantics, `--hostlist`/`--ipset` as filter primitives); `zapret2-engine-reference/reference/arg-ordering.md` (hostlist/ipset are order-independent — no `--payload`-style ordering rule); `zapret2-strategies/reference/preset.md` (where category profiles live in a preset); `zapret2-strategies/reference/profile.md` (a profile's filter + desync anatomy); `nfqueue-wiring.md` (the NFQUEUE rule that consumes the nftset); `blockcheck.md` (autodetection shapes the strategy; hostlist scope is orthogonal); `openwrt-ops` §2 (nftset preferred, ipset fallback policy), §4 (dnsmasq-full), §7 (nftset probe), §8 (dnsmasq-full swap), Appendix A (safe-mode nftset change example).

## Source mapping

Upstream code: zapret2 engine `--hostlist*` / `--ipset*` flag parser (flag syntax and file format are engine-defined). Upstream documentation: openwrt-ops §2 (nftset preferred, ipset deprecated), §4 (dnsmasq-full requirement), §7 (nftset probe procedure), §8 (dnsmasq-full swap), Appendix A (safe-mode dnsmasq nftset change — the procedure this file extends). The `ipset-discord` raw list: community-sourced CIDR list (duplicates + mixed ASNs attested in the list itself).
