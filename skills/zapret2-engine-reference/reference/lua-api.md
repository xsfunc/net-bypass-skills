# lua-api — C functions exposed to Lua & helper libraries

Loaded only when the agent needs to write custom Lua via `--lua-init` or `luaexec`, or to debug a `zapret-lib.lua` helper. Not needed for composing standard `--lua-desync` chains from `zapret-antidpi.lua`. `[evidence: verified]` (function signatures are code-defined in `nfq2/lua.c` and `lua/zapret-lib.lua`).

This card documents the **C functions exposed to Lua** by the engine (`nfq2/lua.c`) and the helper library (`lua/zapret-lib.lua`). For the desync technique functions themselves (`fake`, `multisplit`, …) see `zapret2-strategies/reference/<technique>.md`; for `tls_mod` see `blob.md`.

## Logging

| Function | Effect | Evidence |
|----------|--------|----------|
| `DLOG(s)` | debug log | verified |
| `DLOG_ERR(s)` | error log | verified |
| `DLOG_CONDUP(s)` | conditional log (stdout) | verified |

`[evidence: verified]` (registered in `nfq2/lua.c`).

## IP

| Function | Effect | Evidence |
|----------|--------|----------|
| `ntop(raw_ip)` | binary → string; auto-detects v4/v6 by length (4 = v4, 16 = v6) | verified |
| `pton(string_ip)` | string → binary | verified |

`[evidence: verified]`.

## Bitwise (unsigned 8–48 bit, independent of Lua engine)

| Function | Effect | Evidence |
|----------|--------|----------|
| `bitlshift`, `bitrshift` | shifts | verified |
| `bitand(...)`, `bitor(...)`, `bitxor(...)` | variadic bitwise | verified |
| `bitnot` / `bitnot48` | not (48-bit variant) | verified |
| `bitnot8` / `bitnot16` / `bitnot24` / `bitnot32` | width-specific not | verified |
| `bitget(u, from, to)` | get bits `from`–`to` | verified |
| `bitset(u, from, to, set)` | set bits `from`–`to` to `set` | verified |

`[evidence: verified]`.

## Unsigned numbers (big-endian extract)

| Function | Effect | Evidence |
|----------|--------|----------|
| `u8` / `u16` / `u24` / `u32` / `u48(raw[, offset])` | read N-bit unsigned from `raw` at `offset` | verified |
| `bu8` / `bu16` / `bu24` / `bu32` / `bu48(n)` | build N-bit unsigned → binary string | verified |
| `swap16` / `swap24` / `swap32` / `swap48(n)` | byte-swap | verified |
| `u8add` / `u16add` / `u24add` / `u32add` / `u48add(...)` | add (overflow ignored) | verified |

`[evidence: verified]`.

## Integer division

| Function | Effect | Evidence |
|----------|--------|----------|
| `divint(dividend, divisor)` | integer division (`int64_t` internally) | verified |

`[evidence: verified]`.

## Random (not crypto-strong)

| Function | Effect | Evidence |
|----------|--------|----------|
| `brandom(size)` | random bytes | verified |
| `brandom_az(size)` | random a-z | verified |
| `brandom_az09(size)` | random a-z0-9 | verified |

`[evidence: verified]` (not crypto-strong — use the Crypto group for key material).

## Parsing

| Function | Effect | Evidence |
|----------|--------|----------|
| `parse_hex(hex_string)` | hex string → binary | verified |

`[evidence: verified]`.

## Crypto (crypto-strong via getrandom/getentropy)

| Function | Effect | Evidence |
|----------|--------|----------|
| `bcryptorandom(size)` | crypto-strong random bytes | verified |
| `bxor` / `band` / `bor(data1, data2)` | bytewise xor/and/or | verified |
| `hash("sha256"\|"sha224", data)` | SHA-256 / SHA-224 digest | verified |
| `aes(encrypt, key16/24/32, data16)` | AES block encrypt/decrypt (key 16/24/32 B, single 16 B block) | verified |
| `aes_gcm(encrypt, key, iv12, data[, ad])` → `(ciphertext, atag)` | AES-GCM | verified |
| `aes_ctr(key, iv16, data)` | AES-CTR | verified |
| `hkdf(hash_type, salt, ikm, info, okm_len)` | HKDF key derivation | verified |

`[evidence: verified]`.

## Compression

| Function | Effect | Evidence |
|----------|--------|----------|
| `gunzip_init([windowBits])` | init inflate stream | verified |
| `gunzip_end(zs)` | finalise inflate stream | verified |
| `gunzip_inflate(zs, data[, exp])` | inflate | verified |
| `gzip_init([windowBits[, level[, memlevel]]])` | init deflate stream | verified |
| `gzip_end(zs)` | finalise deflate stream | verified |
| `gzip_deflate(zs, data[, exp])` | deflate (finalize with `nil`/`""`) | verified |

`[evidence: verified]`.

## System

| Function | Effect | Evidence |
|----------|--------|----------|
| `uname()` | system uname | verified |
| `clock_gettime()` → `(sec, nsec)` | hi-res time | verified |
| `clock_getfloattime()` | float time | verified |
| `getpid()` | process id | verified |
| `gettid()` | thread id | verified |
| `stat(filename)` → `{type,size,mtime,inode,dev}` \| `nil` | file stat | verified |
| `localtime` / `unixtime` / `gmtime` / `timelocal` / `timegm` | time conversions | verified |

`[evidence: verified]`.

## Dissection / reconstruction

| Function | Effect | Evidence |
|----------|--------|----------|
| `dissect(raw_ip)` | parse a raw IP packet into a dissect table | verified |
| `reconstruct_dissect(dis[, reconstruct_opts])` | rebuild raw from dissect | verified |
| `reconstruct_tcphdr` / `udphdr` / `icmphdr` / `iphdr` / `ip6hdr(...)` | per-header reconstruct | verified |
| `csum_ip4_fix` / `tcp_fix` / `udp_fix` / `icmp_fix(raw_ip_hdr, raw_l4_hdr, payload)` | checksum fix | verified |

`reconstruct_opts`: `keepsum`, `badsum`, `ip6_preserve_next`, `ip6_last_proto`. `[evidence: verified]` (`ip6_preserve_next` here is the reconstruct-side knob matching `VERDICT_PRESERVE_NEXT` — see `verdicts.md`).

## conntrack

| Function | Effect | Evidence |
|----------|--------|----------|
| `conntrack_feed(dis\|raw[, reconstruct_opts])` → `(track, outgoing_bool)` | feed a packet to conntrack; returns the connection track + whether it is outgoing | verified |

`[evidence: verified]` (conntrack is prerequisite for `ip_autottl`, `--out-range` counting, `l7proto` persistence — see `core-flags.md`).

## IP / iface

| Function | Effect | Evidence |
|----------|--------|----------|
| `get_source_ip(target)` | resolve source IP for a target | verified |
| `get_ifaddrs()` → `{ifname → {index, mtu, flags, ssid, addr[]{addr, netmask, broadcast, dst}, …}}` | interface table; `ssid` only populated when `--filter-ssid` is set (AP router); Windows-only extras: `guid/iftype/index6/speed_xmit/speed_recv/metric4/metric6/conntype` | verified |
| `update_ifaddrs()` | refresh the cached table (cached ≤ 1/sec) | verified |
| `ip2ifname(ip)` | which iface an IP egresses | verified |

`[evidence: verified]` (`ssid` exposure via `get_ifaddrs()` requires `--filter-ssid` — see `filter.md`).

## Sending

| Function | Effect | Evidence |
|----------|--------|----------|
| `rawsend(raw_data[, rawsend_opts])` | send a raw packet | verified |
| `rawsend_dissect(dis[, rawsend_opts[, reconstruct_opts]])` | reconstruct + send a dissect | verified |
| `rawsend_dissect_ipfrag(dis[, options])` | reconstruct + send with IP fragmentation (see `fooling.md` `ipfrag_options`) | verified |
| `rawsend_dissect_segmented(desync[, dis[, mss[, options]]])` | auto TCP segmentation by MSS | verified |
| `rawsend_payload_segmented(desync[, payload[, seq[, options]]])` | segment a payload by seq | verified |
| `raw_packet(ctx)` | fetch the raw representation on demand | verified |

`rawsend_opts`: `repeats`, `fwmark` (Linux), `ifout`. `[evidence: verified]`.

## Payload markers

Absolute positive (offset), absolute negative (from byte past end; `-1` = last byte), and relative markers:

| Marker | Meaning |
|--------|---------|
| `method`, `host`, `endhost`, `sld`, `endsld`, `midsld`, `sniext`, `extlen` | relative positions inside the payload |

| Function | Effect | Evidence |
|----------|--------|----------|
| `resolve_pos(blob, l7payload_type, marker[, zero_based])` | resolve a single marker to a byte offset | verified |
| `resolve_multi_pos(blob, type, marker_list[, zero_based])` | resolve a list of markers | verified |
| `resolve_range(blob, type, marker_list[, strict, zero_based])` | resolve a range from a marker list | verified |

`[evidence: verified]` (`resolve_pos`/`multi_pos`/`range` are code-defined in `nfq2/lua.c`). For the `pos=` desync argument that consumes these markers see `zapret2-strategies/reference/<technique>.md`.

## TLS

| Function | Effect | Evidence |
|----------|--------|----------|
| `tls_mod(blob, modlist[, payload])` | TLS Client Hello mutation — see `blob.md` (do not duplicate here) | verified |
| `tls_dissect(tls, offset, partialOK)` | parse a TLS record at offset; `partialOK` allows partial blocks | verified |
| `tls_reconstruct(tdis)` | rebuild a TLS dissect (handles records, handshakes, split handshakes, partial blocks) | verified |

`tls_reconstruct` parses extensions: `server_name`, `alpn`, `supported_versions`, `compress_certificate`, `signature_algorithms`, `delegated_credentials`, `supported_groups`, `ec_point_formats`, `psk_key_exchange_modes`, `key_share`, `quic_transport_params`. **No DTLS** — DTLS payloads (`dtls_client_hello`/`dtls_server_hello`, see `payload.md`) are not parsed by `tls_dissect`. `[evidence: verified]`.

## HTTP

| Function | Effect | Evidence |
|----------|--------|----------|
| `http_dissect_req(http)` | parse an HTTP request | verified |
| `http_dissect_reply(http)` | parse an HTTP reply | verified |
| `http_reconstruct_req(hdis[, unixeol])` | rebuild an HTTP request dissect | verified |

Header entries carry `{header, header_low, value, pos_start, pos_end, pos_header_end, pos_value_start}`. `[evidence: verified]`.

## URL / host

| Function | Effect | Evidence |
|----------|--------|----------|
| `dissect_url(url)` → `{proto, creds, domain, port, uri}` | parse a URL | verified |
| `dissect_nld(domain, level)` | NLD extraction (`level=2`: `www.microsoft.com` → `microsoft.com`) | verified |
| `genhost(len[, template])` | generate a random hostname | verified |

`[evidence: verified]`.

## autottl

| Function | Effect | Evidence |
|----------|--------|----------|
| `parse_autottl(s)` | `<delta>,<min>-<max>` → table (format mandatory; bare → `parse_autottl: invalid value`) | verified |
| `autottl(incoming_ttl, attl)` | heuristic hop guess from default TTLs 64/128/255 | verified |

`[evidence: verified]` (used by `ip_autottl`/`ip6_autottl` — see `fooling.md`; requires conntrack).

## TCP / IPv6 options

| Function | Effect | Evidence |
|----------|--------|----------|
| `find_tcp_option(options, kind)` | locate a TCP option by kind | verified |
| `find_ip6_exthdr(exthdr, proto)` | locate an IPv6 extension header by proto | verified |
| `insert_ip6_exthdr` / `del_ip6_exthdr` / `fix_ip6_next(...)` | edit the extension-header chain (respect the hopbyhop → hopbyhop2 → destopt → routing → destopt2 → ah order — see `fooling.md`) | verified |

`[evidence: verified]`.

## Instance execution control

| Function | Effect | Evidence |
|----------|--------|----------|
| `instance_cutoff(ctx[, outgoing])` | self-disable the current instance (CPU saver) | verified |
| `lua_cutoff(ctx[, outgoing])` | self-disable all Lua for the connection | verified |
| `execution_plan(ctx)` → array of `{func, func_n, func_instance, range{from,to,upper_cutoff}, payload, payload_filter, arg}` | the resolved execution plan | verified |
| `execution_plan_cancel(ctx)` | cancel the plan | verified |

`[evidence: verified]` (cutoff is the engine's CPU-protection mechanism — see `zapret2-router-deploy/reference/theory.md` §6 "Cutoff — self-disabling for CPU").

## Timers

| Function | Effect | Evidence |
|----------|--------|----------|
| `timer_set(name, func, period_ms, oneshot_bool, data)` | arm a timer | verified |
| `timer_del(name)` | delete a timer | verified |
| `timer_info(name)` → `{name, func, oneshot, period, fires}` | timer status | verified |
| `timer_enum()` | enumerate timers | verified |

Timer function prototype: `function timer(name, data)`. Timers fire **between packet-batch processing** (not perfectly precise). In `--intercept=0` mode nfqws2 keeps running until no timers remain (see `core-flags.md` `--intercept`). `[evidence: verified]`.

## Other Lua libraries (not documented here)

| Library | One-line | Evidence |
|---------|----------|----------|
| `zapret-obfs.lua` | exposes `udp2icmp` with `ccode`/`scode`/`dataxor` args — protocol obfuscation | community-observed |
| `zapret-pcap.lua` | packet capture to `.cap` files | community-observed |
| `zapret-tests.lua` | tests for the C functions above | community-observed |

`[evidence: community-observed]` (these libraries ship with zapret2 but are auxiliary; load via `--lua-init=@lua/<file>.lua` when needed).

## Cross-references

`blob.md` (`tls_mod` — the TLS mutation function, standard blobs); `fooling.md` (`ipfrag_options`, `ip6_*` extension-header order, `parse_autottl`); `verdicts.md` (`VERDICT_PRESERVE_NEXT` / `ip6_preserve_next` reconstruct knob); `core-flags.md` (`--lua-init`, `--intercept`, `--ctrack-disable=0`, `--writable`); `zapret2-strategies/reference/<technique>.md` (desync functions that call these helpers); `zapret2-router-deploy/reference/theory.md` §6 (cutoff, Lua pipeline).

## Source mapping

Upstream code: `nfq2/lua.c` (C functions registered into the Lua VM — `resolve_pos`/`multi_pos`/`range`, bitwise, unsigned, crypto, compression, system, dissection, conntrack, sending, timers); `lua/zapret-lib.lua` (helper wrappers `apply_fooling`, `parse_autottl`, `tls_mod`, `payload_match_filter`, `get_ifaddrs` integration). Upstream documentation: `docs/manual.md` §"C functions", §zapret-lib.lua, §zapret-antidpi.lua.
