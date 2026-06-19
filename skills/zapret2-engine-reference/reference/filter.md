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

## AND-semantics

All filters in a profile act simultaneously: a packet must match `--filter-l3` AND `--filter-tcp`/`--filter-udp` AND `--filter-l7` (AND `--hostlist`/`--ipset`/`--out-range`/`--payload` — see their cards). Miss any one and the profile is skipped — the engine tries the next profile. `[evidence: community-observed]` (semantics attested in upstream documentation; the AND combination is not a single code path but the observable engine behaviour).

## TCP/UDP mutual exclusion

If `--filter-tcp` is specified **without** `--filter-udp`, UDP is **blocked** for that profile (not merely ignored). The converse holds. To handle both transports in one profile, specify both. `[evidence: verified]` (documented upstream flag behaviour).

## `--ipset` / `--hostlist` — filter primitives (one-liners)

These are profile-scope filters too, but their **management** (file format, dnsmasq nftset wiring, auto-hostlist, curation caveats) lives in `zapret2-router-deploy`:

| Flag | Matches by | Detail |
|------|-----------|--------|
| `--hostlist=<file>` / `--hostlist-exclude=<file>` / `--hostlist-domains=<dom>` | SNI/Host domain | `zapret2-router-deploy` (#5) |
| `--ipset=<file>` / `--ipset-exclude=<file>` / `--ipset-ip=<ip>` | IP range | `zapret2-router-deploy` (#5) — required for protocols with no SNI (QUIC, voice, MTProto) |

`[evidence: verified]` (flag syntax); management/details: `zapret2-router-deploy`.

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
- **`--filter-ssid` is Windows-only** (winws2/WinDivert) and is not applied on the router — see `core-flags.md` Windows-only boundary. `[evidence: verified]`

## Cross-references

`payload.md` (per-packet payload filter, `l7proto` vs `l7payload`); `arg-ordering.md` (filter order-independence vs `--payload`/`--out-range` ordering); `zapret2-strategies/reference/profile.md` (how filters compose inside a profile's AND-desync formula); `zapret2-router-deploy` (hostlist/ipset/nftset management, nftables NFQUEUE capture).

## Source mapping

Upstream code: `nfq2/protocol.c:32` (`l7proto_name[]` array — the `--filter-l7` value set). Upstream documentation: zapret2 filter model (port/l3/l7 filters, AND-semantics, TCP/UDP exclusion). No single code path for AND-combination — model distilled from upstream filter documentation.
