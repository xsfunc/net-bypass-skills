# payload — payload-type filter

`--payload` restricts the subsequent `--lua-desync` functions to a specific **payload type** (the kind of L7 content a packet carries). It is a per-packet filter — unlike `--filter-l7`, which is per-connection. It scopes forward until the next `--payload` or the end of the profile (see `arg-ordering.md`). `[evidence: community-observed]` (filter model from upstream documentation).

## Type list

| Group | Types |
|-------|-------|
| Special | `all`, `unknown`, `empty`, `known` |
| HTTP | `http_req`, `http_reply` |
| TLS/SSL | `tls_client_hello`, `tls_server_hello` |
| QUIC | `quic_initial` |
| WireGuard | `wireguard_initiation`, `wireguard_response`, `wireguard_cookie`, `wireguard_keepalive`, `wireguard_data` |
| P2P/messengers | `dht`, `discord_ip_discovery`, `stun` |
| XMPP | `xmpp_stream`, `xmpp_starttls`, `xmpp_proceed`, `xmpp_features` |
| DNS | `dns_query`, `dns_response` |
| Telegram | `mtproto_initial` |

`[evidence: verified]` (the `l7payload` enum is code-defined in `nfq2/protocol.c`; the `L7P_*` constants map to the names above).

## Syntax

```
--payload=tls_client_hello              # one type
--payload=http_req,http_reply           # comma-list
--payload=known                         # any recognised non-empty payload (default)
--payload=all                           # everything, including empty
--payload=~empty                        # negation: all except empty
--payload=~unknown                      # all except unknown
```

`[evidence: verified]` (flag syntax).

## Default = `known`

If `--payload` is omitted, the filter defaults to `known`. The default filter passes any recognised payload (`tls_client_hello`, `http_req`, `quic_initial`, `mtproto_initial`, …) and **rejects** `unknown` and `empty`. `[evidence: verified]` (the default is applied in `payload_match_filter`: `lua/zapret-lib.lua:1074-1079` — `local argpl = l7payload_filter or def or "known"`).

```lua
-- lua/zapret-lib.lua:1074-1079
function payload_match_filter(l7payload, l7payload_filter, def)
    local argpl = l7payload_filter or def or "known"
    local neg = string.sub(argpl,1,1)=="~"
    local pl = neg and string.sub(argpl,2) or argpl
    return neg ~= (in_list(pl, "all") or in_list(pl, l7payload) or in_list(pl, "known") and l7payload~="unknown" and l7payload~="empty")
end
```

Consequence: by default only the **first** payload-bearing packet of a protocol (e.g. `tls_client_hello`, `quic_initial`, `mtproto_initial`) is processed; subsequent packets are `unknown` and skipped. To process every packet use `--payload=all` or `--payload=mtproto_initial,unknown`. `[evidence: verified]`

## `l7proto` vs `l7payload`

Two different notions — do not conflate them:

| Notion | Scope | Set on | Persists? |
|--------|-------|--------|-----------|
| `l7proto` (`--filter-l7`) | whole connection | first recognised packet | yes — saved in conntrack, reused for every later packet of the connection |
| `l7payload` (`--payload`) | single packet | each packet individually | no — re-derived per packet |

Example: a TLS connection has `l7proto = tls` for every packet (after the first), but `l7payload = tls_client_hello` only on the first data packet and `unknown` on the rest. `[evidence: verified]` (conntrack saves `l7proto`: `nfq2/desync.c` — `if (ctrack) l7proto = ctrack->l7proto`; `l7payload` is recomputed per packet).

So `--filter-l7=tls` matches all packets of the connection, while `--payload=tls_client_hello` matches only the first. `[evidence: verified]`

## Multiple `--payload` in one profile

`--payload` may repeat inside a profile; each occurrence scopes the following `--lua-desync` lines until the next `--payload`:

```
--payload=tls_client_hello --lua-desync=fake:blob=fake_default_tls:tcp_md5
--payload=http_req         --lua-desync=multisplit:pos=method+2
```

The first `fake` runs only on TLS Client Hello; the `multisplit` runs only on HTTP requests. See `arg-ordering.md` for the ordering rule. `[evidence: verified]` (scoped filter reset); `[evidence: community-observed]` (composition pattern).

## Examples (router)

```
# Only TLS Client Hello
--filter-l7=tls --payload=tls_client_hello --lua-desync=fake:blob=fake_default_tls

# HTTP request and reply
--payload=http_req,http_reply --lua-desync=multisplit

# All recognised types (the default — explicit)
--payload=known --lua-desync=fake

# Different strategies per payload
--payload=tls_client_hello --lua-desync=fake:ip_ttl=1
--payload=http_req         --lua-desync=split:pos=method+2
```

`[evidence: community-observed]` (composition shapes from upstream presets); `[evidence: verified]` (flag syntax).

## Gotchas

- **Default `known` drops `unknown`.** If you expect a strategy to fire on every packet but omit `--payload`, only the first recognised packet is processed. Use `--payload=all` to include empty/unknown. `[evidence: verified]`
- **`--payload` is per-packet, `--filter-l7` is per-connection.** A profile with `--filter-l7=tls` and no `--payload` matches all TLS packets but only *acts* on `tls_client_hello` (default `known`). `[evidence: verified]`
- **`--payload` must precede `--lua-desync`.** Reversed order silently leaves the desync unscoped (it runs against the previous/`known` filter, not the intended one). See `arg-ordering.md`. `[evidence: verified]`
- **`--payload` for protocols with no SNI.** QUIC/voice/Telegram have no hostname; pair `--payload=quic_initial` with `--ipset` (see `filter.md` / `zapret2-router-deploy`), not `--hostlist`. `[evidence: community-observed]`

## Cross-references

`arg-ordering.md` (the `--payload`-before-`--lua-desync` rule, scope reset); `filter.md` (`--filter-l7` per-connection vs `--payload` per-packet); `out-range.md` (further narrowing by packet number); `zapret2-strategies/reference/profile.md` (where `--payload` sits in a profile's AND-desync formula).

## Source mapping

Upstream code: `lua/zapret-lib.lua:1074-1079` (`payload_match_filter` — default `known`, negation handling); `nfq2/protocol.c` (`l7payload` enum / `L7P_*` constants — the type set); `nfq2/desync.c` (`ctrack->l7proto` reuse — per-connection vs per-packet distinction).
