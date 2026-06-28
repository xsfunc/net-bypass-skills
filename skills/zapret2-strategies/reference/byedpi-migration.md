# byedpi → nfqws2 migration

This card exists so the agent can read a phone-side byedpi config and translate it into an nfqws2 `--lua-desync` config line for the router. It complements `migration.md` (nfqws1 → nfqws2): same shape, second source column.

## byedpi flag reference (desync-relevant only)

Distilled from the byedpi README (`hufrea/byedpi`, main branch, 2026-06-28). Proxy/daemon/cache/network flags (`-i`, `-p`, `-D`, `-c`, `-I`, `-b`, `-T`, `-N`, `-U`, `-F`, `-K`, `-u`, `-y`) are omitted — they have no nfqws2 analog (byedpi is a SOCKS server; nfqws2 is an NFQUEUE packet modifier).

### Position syntax `pos_t`

byedpi positions use a mini-grammar with **no nfqws2 equivalent**:

```
pos_t = offset[:repeats:skip][+flag1[flag2]]
```

- `offset` — absolute byte position; negative without flags → `offset + packet_size` (from end).
- `:repeats:skip` — generates `repeats` split points spaced `skip` apart: `1:3:5` → positions 1, 6, 11. **No nfqws2 analog** — nfqws2 requires an explicit comma-list: `pos=1,6,11`.
- `+s` — add SNI offset → nfqws2 `sniext+N`.
- `+h` — add Host offset → nfqws2 `host+N`.
- `+n` — zero offset → nfqws2 `0` (absolute start).
- `+e` — end → nfqws2 `-N` (from end) or `endhost`/`endsld`.
- `+m` — middle → nfqws2 `midsld`/`midhost`.

`+s`/`+h`/`+m`/`+e` can combine: `0+sm` = middle of SNI. nfqws2 markers compose with `+N`/`-N` arithmetic only (e.g. `sniext+3`), not flag combinations — there is no `sniext+midsld` shorthand; use the explicit marker.

### Desync flags

| byedpi | Semantics | Evidence |
|--------|-----------|----------|
| `-s, --split <pos_t>` | Forward-order split; repeatable for multiple points | README |
| `-d, --disorder <pos_t>` | Reverse-order split (tail sent with TTL=1, lost, retransmitted after head) | README |
| `-o, --oob <pos_t>` | Insert 1 OOB byte (URG) at split position; data-phase | README |
| `-q, --disoob <pos_t>` | disorder + OOB combined | README |
| `-f, --fake <pos_t>` | Fake first segment, then real tail, then real head via retransmission | README |
| `-t, --ttl <num>` | TTL for fake packet (default 8) | README |
| `-S, --md5sig` | TCP MD5 Signature option on fake | README |
| `-O, --fake-offset <pos_t>` | Shift fake data start | README |
| `-l, --fake-data <file\|:str>` | Custom fake payload | README |
| `-e, --oob-data <char>` | OOB byte (default 'a') | README |
| `-n, --fake-sni <str>` | Dynamic SNI in fake; `?`/`#`/`*` wildcards | README |
| `-Q, --fake-tls-mod <flag>` | `rand`/`orig`/`msize=n` fake TLS mods | README |
| `-M, --mod-http <h[,d,r]>` | `hcsmix`/`dcsmix`/`rmspace` HTTP header tampering | README |
| `-r, --tlsrec <pos_t>` | Split TLS record into multiple records at offset (record-layer) | README |
| `-m, --tlsminor <ver>` | Change TLS minor version byte | README |
| `-a, --udp-fake <count>` | N fake UDP packets | README |
| `-Y, --drop-sack` | Ignore SACK, force kernel retransmission | README |
| `-A, --auto <t,r,s,n>` | Per-connection retry state machine; groups split by `--auto` | README |
| `-L, --auto-mode <0-3>` | Auto cache/sort mode | README |
| `-R, --round <num[-numr]>` | Which request(s) to apply desync to (default 1) | README |
| `-g, --def-ttl <num>` | Global TTL for all outgoing connections | README |
| `-H, --hosts <file\|:str>` | Domain scoping | README |

## Migration map

| byedpi | nfqws2 | Notes | Evidence |
|--------|--------|-------|----------|
| `--split 3+s --split 7` | `multisplit:pos=sniext+3,7` | Merge repeated `--split` into one comma-list. Position 1 auto-deleted in nfqws2 (use `2` not `1`). | verified |
| `--disorder 7` | `multidisorder:pos=7` | byedpi uses TTL=1+retransmission; nfqws2 uses out-of-order send + server reassembly. Same wire-effect, different mechanism. | verified |
| `--fake 7` | `fakedsplit:pos=7` (preferred) or `fake:blob=...` | byedpi fake = fake-first-segment + real-tail + real-head-retransmit. `fakedsplit` matches best (split surrounded by fakes, same seq). Bare `fake` = area-fire, no split. | verified |
| `--disorder 1 --fake 7` | `fakeddisorder:pos=7` | Fake + disorder combined → `fakeddisorder` (reverse-order split + fakes). | verified |
| `--ttl 8` | `:ip_ttl=8` | Fooling flag on the fake instance. | verified |
| `--md5sig` | `:tcp_md5` | Fooling flag. Linux-only in byedpi; same limitation in nfqws2. | verified |
| `--fake-data=:GET /...` | `fake:blob=...` with inline hex or `--blob=name:@file` | nfqws2 requires explicit `blob=` (no auto-selection). | verified |
| `--fake-sni ex?mple.com` | `hostfakesplit:host=example.com` or `fake:tls_mod=sni=example.com` | `?`/`#`/`*` wildcards → no exact nfqws2 analog. `hostfakesplit` uses `genhost` (own generation, no wildcard chars); `tls_mod=sni=` is static. Wildcard randomization requires `luaexec`. | community-observed |
| `--fake-tls-mod rand` | `:tls_mod=rnd` | Randomize SessionID/Random/KeyExchange. | verified |
| `--fake-tls-mod orig` | `fake:tls_mod=...` + `tls_client_hello_clone` | `orig` = use real ClientHello as fake. nfqws2's `tls_client_hello_clone` prepares a fake from the real CH — new nfqws2 capability. See `misc-desync.md`. | verified |
| `--fake-tls-mod msize=n` | no direct analog | Fake size limiting (negative = shrink). No nfqws2 flag; `luaexec` can resize a blob. | hypothesis |
| `--mod-http hcsmix` | `http_hostcase[:spell=????]` | Mix hostname case. nfqws2 `spell` must be exactly 4 chars. | verified |
| `--mod-http dcsmix` | `http_domcase` | Mix domain case. | verified |
| `--mod-http rmspace` | no direct analog | "Host: name" → "Host:name\t" (space-removal+tab). No nfqws2 HTTP-fooling flag does this. | community-observed |
| `--udp-fake 3` | `fake:repeats=3:blob=<quic_blob>` | nfqws2 fake supports UDP (QUIC); `repeats` controls count. | verified |
| `--round 2` | `--in-range=d2` (or `d2-d3` for range) | byedpi "which request"; nfqws2 packet-range filter. See `out-range.md`. | verified |

## Gaps & divergences (no clean nfqws2 analog)

These byedpi features have **no direct nfqws2 equivalent**. Migrating them requires a substitute technique, `luaexec`, or keeping them on the phone.

### `--tlsrec` — TLS record-layer fragmentation (NO ANALOG)

byedpi splits a TLS record into multiple records by inserting a new 5-byte record header at the offset (e.g. `--tlsrec 3+s` splits inside the SNI). This is **record-layer** fragmentation, not TCP segmentation.

- **Do NOT map to `tcpseg`/`multisplit`** — those split TCP segments, not TLS records. Splitting a TCP segment inside the SNI does not break the TLS record header that the DPI parses.
- No nfqws2 function performs TLS record splitting. Closest substitute: `luaexec` to rewrite the record layer, but this is custom code, not a built-in escape.
- **Recommendation:** keep `--tlsrec` on the phone (byedpi), or report-and-ask the operator whether a `luaexec` custom record-splitter is warranted.

### `--oob` / `--disoob` — data-phase OOB (DIFFERENT from nfqws2 `oob`)

byedpi `--oob 3` inserts an OOB byte (URG) at a split position in the **data packet** (phase 1+). nfqws2 `oob` inserts an OOB byte at the **SYN** phase (seq shift) — it is SYN-based, not split-based.

- The names are identical but the mechanisms differ. nfqws2 `oob` cannot target an arbitrary split position; it shifts seq at SYN and inserts 1 byte in the first data packet.
- byedpi `--disoob` (disorder + OOB combo) has no nfqws2 analog at all.
- **Recommendation:** flag to operator. nfqws2 `oob` is the closest name but does not reproduce byedpi's data-phase OOB-at-position behavior.

### `--drop-sack` — kernel SACK suppression (NO ANALOG)

byedpi tells the client kernel to ignore TCP SACK, forcing full retransmission. nfqws2 operates at NFQUEUE and does not control the client kernel's TCP stack behavior.

- No nfqws2 flag controls SACK handling. This is a host-kernel setting.
- **Recommendation:** keep on the phone. On the router, the client OS controls SACK.

### `--auto` / `--auto-mode` — per-connection retry state machine (DIFFERENT from `circular`)

byedpi `--auto=torst --fake -1 --ttl 5` means: try without bypass first; if a torst event occurs, retry with the next option group. This is a **per-connection** state machine: the same connection retries with different params.

nfqws2 `circular` is a **per-host** orchestrator: it rotates strategies across **separate** connections based on a failure counter stored per-host in `autostate`. It does not retry within the same connection.

- Different abstraction levels: byedpi retries the same connection; `circular` rotates the strategy for the next connection to the same host.
- `circular` also requires `--in-range=-sN` (incoming traffic redirection) to observe RST/HTTP-redirect — byedpi's `--auto` observes SSL errors and redirects as a SOCKS proxy.
- **Recommendation:** map conceptually (auto-fallback) but warn the operator that `circular` operates across connections, not within one. See `reference/circular.md`.

### `--tlsminor` — TLS version byte change (NO ANALOG)

byedpi changes the third byte of the TLS record (minor version). No nfqws2 built-in flag does this. `luaexec` could mutate the packet, but there is no standard function.

### `--def-ttl` — global outgoing TTL (NO ANALOG)

byedpi sets TTL for all outgoing connections to avoid detection of non-standard/reduced TTL. This is a client-kernel setting. nfqws2 has no global-TTL control (it sets `ip_ttl` per-fake only via fooling flags). On the router, global TTL would be an nftables rule outside nfqws2 scope.

### `--fake-offset` — fake start offset (NO ANALOG)

byedpi shifts the start of fake data relative to the original request. nfqws2 `fake`/`fakedsplit`/`fakeddisorder` do not expose a fake-offset parameter; the blob is sent as-is from position 0. `luaexec` could construct a custom blob with an offset.

## Position-syntax asymmetries (summary)

| byedpi | nfqws2 | Comment |
|--------|--------|---------|
| `3+s` | `sniext+3` | byedpi `+s` = SNI-relative; nfqws2 marker = `sniext` |
| `3+h` | `host+3` | byedpi `+h` = Host-relative; nfqws2 marker = `host` |
| `0+sm` | `midsld` (TLS) / `midhost` (HTTP) | byedpi combines `s`+`m`; nfqws2 uses the explicit middle marker for the protocol |
| `1:3:5` (repeat-skip) | `pos=1,6,11` (explicit list) | byedpi generates points; nfqws2 requires explicit list |
| `-7` (negative, no flags) | `-7` (from end) | Same semantics: `offset + packet_size` |
| `N+e` (end flag) | `endhost`/`endsld`/`-N` | byedpi `+e` = end; nfqws2 uses end-markers or negative offset |

## Cross-references

Technique semantics (destination side): `reference/fake.md`, `reference/multisplit.md`, `reference/multidisorder.md`, `reference/fakedsplit.md`, `reference/fakeddisorder.md`, `reference/hostfakesplit.md`, `reference/oob.md`, `reference/circular.md`, `reference/misc-desync.md` (`tls_client_hello_clone`). HTTP-fooling detail: `reference/http-fooling.md`. Fooling flags: `../../zapret2-engine-reference/reference/fooling.md`. Master nfqws1 migration + marker table: `migration.md`.

