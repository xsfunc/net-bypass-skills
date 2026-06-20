# filter — profile-scope transport & protocol filters

Profile-scope filters decide which packets a profile reacts to. They are the **first half** of a profile's formula ("for this traffic … apply this bypass"). They live inside a `--new`-separated profile block and act on the whole profile (order-independent among themselves — see `arg-ordering.md`). They are distinct from the initial capture filter (nftables/NFQUEUE on the router; `zapret2-router-deploy`), which runs before nfqws2 sees the packet. `[evidence: community-observed]` (filter model from upstream documentation).

## Flags

### `--filter-l3=ipv4|ipv6`

Restrict to IP version. Comma-list allowed.

```
--filter-l3=ipv4
--filter-l3=ipv4,ipv6
```

`[evidence: verified]` (flag syntax is code-defined).

### `--filter-tcp=[~]port1[-port2]|*`

TCP port filter. `port`, `port1-port2` range, `~port` negation (all except), `*` all ports, comma-list. Matches source **and** destination ports. `[evidence: verified]` (flag syntax, code-defined).

```
--filter-tcp=80,443
--filter-tcp=80-443
--filter-tcp=~443
--filter-tcp=*
```

### `--filter-udp=[~]port1[-port2]|*`

UDP port filter. Same grammar as `--filter-tcp`. `[evidence: verified]`

```
--filter-udp=443           # QUIC
--filter-udp=53,443
```

### `--filter-l7=proto[,proto,...]`

Application-protocol filter. Recognised values: `all`, `unknown`, `known`, `http`, `tls`, `quic`, `wireguard`, `dht`, `discord`, `stun`, `xmpp`, `dns`, `mtproto`. `[evidence: verified]` (the `l7proto_name[]` array is code-defined: `nfq2/protocol.c:32`).

```
--filter-l7=http
--filter-l7=tls,http
--filter-l7=quic
--filter-l7=known
```

`known` = all recognised protocols; `unknown` = unrecognised; `all` = both. `[evidence: verified]`

### `--filter-icmp=type[:code]|*`

ICMP filter. `type` is the ICMP type number; `:code` (optional) narrows by code — omitted code = any code. `*` = all ICMP. **icmp automatically includes icmpv6** (the two share one filter group). `[evidence: verified]` (flag syntax is code-defined; icmp/auto-icmpv6 inclusion per `docs/manual.md` §nfqws2-specific).

```
--filter-icmp=8            # ICMP echo request (any code)
--filter-icmp=3:1          # ICMP dest-unreachable, code 1
--filter-icmp=*            # all ICMP + icmpv6
```

### `--filter-ipp=proto|*`

Raw IP protocol filter by IANA protocol number (e.g. `--filter-ipp=6` for TCP, `--filter-ipp=17` for UDP, `--filter-ipp=132` for SCTP). `*` = all. This is the **fourth** transport-group filter (alongside tcp/udp/icmp) and is needed for protocols nfqws2 does not dissect at L4 (SCTP, GRE, …). `[evidence: verified]` (flag syntax is code-defined per `docs/manual.md` §nfqws2-specific).

```
--filter-ipp=132           # SCTP
--filter-ipp=*             # any raw IP protocol
```

## AND-semantics

All filters in a profile act simultaneously: a packet must match `--filter-l3` AND (`--filter-tcp`/`--filter-udp`/`--filter-icmp`/`--filter-ipp` — the four transport groups, see below) AND `--filter-l7` (AND `--hostlist`/`--ipset`/`--out-range`/`--payload` — see their cards). Miss any one and the profile is skipped — the engine tries the next profile. `[evidence: community-observed]` (semantics attested in upstream documentation; the AND combination is not a single code path but the observable engine behaviour).

## Transport group mutual exclusion (tcp/udp/icmp/ipp)

The four transport filter groups (`--filter-tcp`, `--filter-udp`, `--filter-icmp`, `--filter-ipp`) combine by **OR**: a packet matching *any* specified group passes the transport-layer filter. But if **any** of the four is specified, the **others are blocked unless also defined**. So:

- `--filter-tcp=443` alone ⇒ UDP, ICMP, and raw-IP packets are all blocked for the profile.
- `--filter-tcp=* --filter-udp=*` ⇒ TCP and UDP pass, ICMP and raw-IP blocked.
- `--filter-ipp=6` alone ⇒ **blocks everything** (see gotcha below) — `--filter-ipp` filters the raw-IP layer but does not implicitly enable TCP/UDP dissection.

`[evidence: verified]` (documented upstream flag behaviour; the 4-group OR-with-unspecified-blocked model per `docs/manual.md` §nfqws2-specific). The earlier "TCP/UDP mutual exclusion" rule is the 2-group special case of this.

## `--ipset` / `--hostlist` — filter primitives (one-liners)

These are profile-scope filters too, but their **management** (file format, dnsmasq nftset wiring, auto-hostlist, curation caveats) lives in `zapret2-router-deploy`:

| Flag | Matches by | Detail |
|------|-----------|--------|
| `--hostlist=<file>` / `--hostlist-exclude=<file>` / `--hostlist-domains=<dom>` | SNI/Host domain | `zapret2-router-deploy` (#5) |
| `--ipset=<file>` / `--ipset-exclude=<file>` / `--ipset-ip=<ip>` | IP range | `zapret2-router-deploy` (#5) — required for protocols with no SNI (QUIC, voice, MTProto) |

`[evidence: verified]` (flag syntax); management/details: `zapret2-router-deploy`.

## Profile-management flags

These tune the profile itself (not the packet match) and live inside the `--new`-separated block:

| Flag | Effect | Evidence |
|------|--------|----------|
| `--skip` | ignore the profile — no-op, the engine skips it (debug/audit toggle) | verified |
| `--name=<name>` | GUI/audit label only — does not affect matching | verified |
| `--template[=<name>]` | mark the profile as a **template** — not executed directly, only referenced via `--import` | verified |
| `--import=<name>` | copy settings from a named template, overwriting the current profile (DRY reuse of filter/desync blocks) | verified |
| `--cookie[=<string>]` | set `desync.cookie` for every instance in the profile (per-profile default override) | verified |

`[evidence: verified]` (flag syntax is code-defined per `docs/manual.md` §profile management). `--template`/`--import` is a **new nfqws2 DRY mechanism** with no nfqws1 analog — it lets a preset define a reusable template profile and have several real profiles import+specialise it instead of duplicating filter/desync blocks.

## Combined example (router)

```
--filter-tcp=80,443 --filter-l7=http,tls --hostlist=/opt/zapret2/lists/youtube.txt
--out-range=-d10 --payload=tls_client_hello
--lua-desync=fake:blob=fake_default_tls
```

Port AND protocol AND hostlist AND range AND payload — all must match. `[evidence: community-observed]` (composition shape from upstream presets); `[evidence: verified]` (flag syntax).

## Gotchas

- **Over-narrow AND silently no-ops a profile.** A profile that never matches is not an error — the engine just skips it. Widen one filter at a time when debugging "strategy present but not firing". `[evidence: community-observed]`
- **`--filter-l7` is per-connection, `--payload` is per-packet.** `--filter-l7=tls` matches every packet of a TLS connection; `--payload=tls_client_hello` matches only the first. See `payload.md`. `[evidence: verified]`
- **No `--filter-udp` ⇒ UDP blocked.** A TCP-only profile silently drops QUIC; add a UDP profile for QUIC/voice. `[evidence: verified]`
- **`--filter-ipp=6` alone does NOT allow TCP.** It blocks everything because `--filter-tcp` is unset. To filter a raw IP protocol alongside TCP/UDP, specify `--filter-ipp=<proto> --filter-tcp=* --filter-udp=*` (or the relevant subset). The 4 groups (tcp/udp/icmp/ipp) combine by OR; if any is specified, the others are blocked unless defined. `[evidence: verified]`
- **`--filter-ssid` is nfqws2/Linux** (not Windows-only). `--filter-ssid=ssid1[,ssid2,...]` filters by client WiFi SSID on an AP router (upstream `docs/manual.md` §nfqws2-specific). The Windows winws2 analogue is `--ssid-filter` (different flag name). On an OpenWrt AP it is applicable: set `--filter-ssid` and `get_ifaddrs()` exposes `ssid` per interface (see `lua-api.md` → IP/iface). `[evidence: verified]` (flag is nfqws2/Linux; winws2 analogue is `--ssid-filter`).

## Cross-references

`payload.md` (per-packet payload filter, `l7proto` vs `l7payload`); `arg-ordering.md` (filter order-independence vs `--payload`/`--out-range` ordering); `zapret2-strategies/reference/profile.md` (how filters compose inside a profile's AND-desync formula); `zapret2-router-deploy` (hostlist/ipset/nftset management, nftables NFQUEUE capture).

## Source mapping

Upstream code: `nfq2/protocol.c:32` (`l7proto_name[]` array — the `--filter-l7` value set). Upstream documentation: `docs/manual.md` §nfqws2-specific (`--filter-ssid`, `--filter-icmp`, `--filter-ipp`, 4-group OR model), §profile management (`--skip`/`--name`/`--template`/`--import`/`--cookie`); zapret2 filter model (port/l3/l7 filters, AND-semantics, transport-group exclusion). No single code path for AND-combination — model distilled from upstream filter documentation.
