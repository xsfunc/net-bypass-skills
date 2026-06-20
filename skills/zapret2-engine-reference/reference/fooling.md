# fooling — per-desync fooling flags

Fooling flags are per-desync packet modifiers appended after the technique's own args, colon-separated: `--lua-desync=<func>:<func-args>:<fooling>:<fooling>...`. They make fake/modified packets **pass the DPI** but **get dropped by the real server** (or vice versa), so the DPI is confused while the legitimate connection survives. They are applied by `apply_fooling()` in `lua/zapret-lib.lua`. `[evidence: verified]` (fooling application path is code-defined).

This card is the **canonical flag reference**. Which fooling applies to which technique (fakes-only vs all-segments vs real-segment) and the nfqws1→nfqws2 migration table live in `zapret2-strategies/migration.md`.

## IP / IPv4

| Flag | Format | Effect | Evidence |
|------|--------|--------|----------|
| `ip_ttl=N` | `ip_ttl=5` | set IPv4 TTL | verified |
| `ip_autottl=delta,min-max` | `ip_autottl=-1,3-20` | auto-detect TTL from incoming packets. **Format mandatory** (`delta,min-max`); bare `:ip_autottl` → `parse_autottl: invalid value`. Requires conntrack (`--ctrack-disable=0`). | verified |
| `ip_id=seq\|rnd\|zero\|none` | `ip_id=seq` | IP ID manipulation mode. `seq` = per-connection incrementing, `rnd` = random, `zero` = force 0, `none` = leave intact (default). | verified |
| `ip_id_conn` | `ip_id_conn` | per-connection IP ID mode (sequence scoped to the connection, not global). | verified |

## IPv6

| Flag | Format | Effect | Evidence |
|------|--------|--------|----------|
| `ip6_ttl=N` | `ip6_ttl=3` | set IPv6 Hop Limit (TTL analogue) | verified |
| `ip6_autottl=delta,min-max` | `ip6_autottl=-2,3-20` | auto Hop Limit for IPv6. Same format/conntrack rules as `ip_autottl`. | verified |

## IPv6 Extension Headers (size 6+N×8 bytes unless noted)

| Flag | Effect | Evidence |
|------|--------|----------|
| `ip6_hopbyhop[=hex]` | add Hop-by-Hop header (default `\x00\x00\x00\x00\x00\x00`) | verified |
| `ip6_hopbyhop2[=hex]` | add a second Hop-by-Hop header | verified |
| `ip6_destopt[=hex]` | add Destination Options header (unfragmentable part) | verified |
| `ip6_destopt2[=hex]` | add a second Destination Options header (fragmentable part) | verified |
| `ip6_routing[=hex]` | add Routing header | verified |
| `ip6_ah[=hex]` | add (truncated) Authentication Header. Size **6+N×4** bytes; default `\x00\x00` + 4 random bytes. | verified |

## IP fragmentation (`ipfrag_options`)

| Flag | Format | Effect | Evidence |
|------|--------|--------|----------|
| `ipfrag=<func>` | `ipfrag=ipfrag2` | IP fragmentation function name; default `ipfrag2` (splits into 2 fragments). Custom functions allowed (receive a dissect, return an array of fragment dissects). | verified |
| `ipfrag_disorder` | (none) | send fragments in reverse order. | verified |
| `ipfrag_pos_udp=<N>` | `ipfrag_pos_udp=8` | fragment split position for UDP, default 8, **must be a multiple of 8**. | verified |
| `ipfrag_pos_tcp=<N>` | `ipfrag_pos_tcp=32` | fragment split position for TCP, default 32, **must be a multiple of 8**. | verified |
| `ipfrag_next` | (none) | manipulate the IPv6 "next protocol" field — attack on ipv6 extension-header chaining (combine with `ip6_*` extension headers; see `verdicts.md` `VERDICT_PRESERVE_NEXT`). | verified |

`[evidence: verified]` (the `ipfrag_options` block is applied in `apply_fooling()`, `lua/zapret-lib.lua`; default `ipfrag2` and the multiple-of-8 position constraint per `docs/manual.md` §fooling). `ipfrag` is unsupported by `fakedsplit`/`fakeddisorder`/`hostfakesplit` — see `zapret2-strategies/migration.md`.

## TCP

| Flag | Format | Effect | Evidence |
|------|--------|--------|----------|
| `tcp_seq=N` | `tcp_seq=10000` | add N to the TCP sequence number ("badseq" fooling) | verified |
| `tcp_ack=N` | `tcp_ack=-66000` | add N to the TCP ack number ("badack"; usually negative) | verified |
| `tcp_ts=N` | `tcp_ts=1000` | add N to the TCP timestamp value | verified |
| `tcp_md5[=hex]` | `tcp_md5` or `tcp_md5=0x...` | add TCP MD5 signature option (RFC 2385), 16 bytes; default random | verified |
| `tcp_flags_set=<list>` | `tcp_flags_set=PSH,URG` | set TCP flags (list: `FIN,SYN,RST,PSH,ACK,URG,ECE,CWR`) | verified |
| `tcp_flags_unset=<list>` | `tcp_flags_unset=ACK` | unset TCP flags (e.g. "datanoack") | verified |
| `tcp_ts_up` | (none) | move the TCP timestamp option to the front of the header. Linux workaround: lets Linux drop bad-ack packets without needing badseq. | verified |
| `tcp_nop_del` | (none) | delete TCP NOP (padding) options from the header. | verified |

## Reconstruct / custom

| Flag | Effect | Evidence |
|------|--------|----------|
| `badsum` | make the L4 checksum invalid | verified |
| `fool=<func>` | call a user-defined fooling function `fool_func(dis, fooling_options)` | verified |

## nfqws1 combonyms (pointer)

nfqws1 had pre-combined fooling names; nfqws2 exposes the primitives. Common mappings (full table in `zapret2-strategies/migration.md`):

| nfqws1 | nfqws2 | Evidence |
|--------|--------|----------|
| `md5sig` | `tcp_md5` | verified |
| `badseq` (SYN) | `tcp_seq=-10000` | verified |
| `badseq` (data) / `badack` | `tcp_ack=-66000` | verified |
| `datanoack` | `tcp_flags_unset=ACK` | verified |
| `hopbyhop` / `destopt` / `ipfrag1` | `ip6_hopbyhop` / `ip6_destopt` / `ipfrag` | verified |
| `--dpi-desync-autottl=…` | `:ip_autottl=delta,min-max` (format mandatory) | verified |

## Examples

```
# Simple TTL
--lua-desync=fake:ip_ttl=5

# Auto TTL (format mandatory, needs conntrack)
--lua-desync=fake:ip_autottl=-1,3-20

# TCP MD5 signature
--lua-desync=fake:tcp_md5

# badseq + badack (classic) — tcp_ts_up required on Linux for badack-without-badseq
--lua-desync=fakedsplit:tcp_seq=-10000:tcp_ack=-66000:tcp_ts_up

# IPv6 extension headers
--lua-desync=fake:ip6_hopbyhop:ip6_destopt

# Unset ACK (datanoack)
--lua-desync=fake:tcp_flags_unset=ACK

# Combined fooling
--lua-desync=fake:ip_ttl=1:tcp_md5:tcp_ack=-66000
```

`[evidence: verified]` (flag syntax, application via `apply_fooling()`).

## Gotchas

- **`ip_autottl` / `ip6_autottl` require conntrack** (`--ctrack-disable=0`) and the `delta,min-max` format — bare `:ip_autottl` errors. See `core-flags.md`. `[evidence: verified]`
- **`tcp_ts_up` must accompany `tcp_ack` on Linux** when using `badack`/`badseq`-for-data without `badseq`-for-SYN: Linux only drops bad-ack packets when the TCP timestamp option is first in the header. `[evidence: verified]`
- **Fooling target varies by technique.** Fakes-only (`fake`, `fakedsplit`, `fakeddisorder`, `hostfakesplit`) vs all-segments (`multisplit`, `multidisorder`, `multidisorder_legacy`) vs real-segment (`tcpseg`, `oob` — destructive fooling drops real data). `ipfrag` is unsupported by `fakedsplit`/`fakeddisorder`/`hostfakesplit`. See `zapret2-strategies/migration.md`. `[evidence: verified]`
- **Fooling is mandatory for `fake` on TCP.** A fake without a limiting fooling (`tcp_md5`, `ip_ttl`, `badsum`, …) desyncs the stream — the server accepts the fake as real data and the connection breaks. See `zapret2-strategies/reference/fake.md`. `[evidence: verified]`
- **`tcp_flags_set` / `tcp_flags_unset` take a comma-list** of flag names from `FIN,SYN,RST,PSH,ACK,URG,ECE,CWR`. `[evidence: verified]`
- **`ipfrag_pos_udp`/`ipfrag_pos_tcp` must be a multiple of 8.** The IPv6 fragmentable-part offset is an 8-byte unit; a non-multiple silently mis-splits. Defaults: UDP 8, TCP 32. `[evidence: verified]`
- **IPv6 extension-header insertion order is fixed.** The engine inserts in the order hopbyhop → hopbyhop2 → destopt → routing → destopt2 → ah. Mixing or reordering the `ip6_*` flags breaks the "next protocol" chain (each header's `next-header` field must point to the following header's type). Use `VERDICT_PRESERVE_NEXT` (see `verdicts.md`) to keep the chain consistent when manipulating `ipfrag_next`. `[evidence: verified]`

## Cross-references

`zapret2-strategies/migration.md` (full nfqws1→nfqws2 fooling migration table, per-technique fooling applicability, `ipfrag`/seqovl cross-technique gotchas); `zapret2-strategies/reference/<technique>.md` (which fooling each technique accepts — e.g. `fake.md` "fooling is mandatory on TCP"); `core-flags.md` (`--ctrack-disable=0` requirement for `ip_autottl`); `verdicts.md` (`VERDICT_PRESERVE_NEXT` for `ipfrag_next` + ipv6 ext-header chaining).

## Source mapping

Upstream code: `lua/zapret-lib.lua` (`apply_fooling()` — fooling application path, `ipfrag_options` block, `parse_autottl` — `ip_autottl` format validation). Upstream documentation: `docs/manual.md` §fooling (`ip_id`/`ip_id_conn`, `tcp_nop_del`, `ipfrag_options`, ipv6 extension-header insertion order); zapret2 fooling flag reference (the full fooling-flag list).
