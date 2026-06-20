# tls_client_hello_clone / rst / udplen / dht_dn / synack / synack_split — misc desync functions

## Lua signatures

`function tls_client_hello_clone(ctx, desync)` — `lua/zapret-antidpi.lua:367-389` `[evidence: verified]` CLI: `--lua-desync=tls_client_hello_clone[:arg=...]`

`function rst(ctx, desync)` — `lua/zapret-antidpi.lua:421-442` `[evidence: verified]` CLI: `--lua-desync=rst[:arg=...]`

`function udplen(ctx, desync)` — `lua/zapret-antidpi.lua:1198-1230` `[evidence: verified]` CLI: `--lua-desync=udplen[:arg=...]`

`function dht_dn(ctx, desync)` — `lua/zapret-antidpi.lua:1235-1250` `[evidence: verified]` CLI: `--lua-desync=dht_dn[:arg=...]`

`function synack(ctx, desync)` — `lua/zapret-antidpi.lua:297-311` `[evidence: verified]` CLI: `--lua-desync=synack[:arg=...]`

`function synack_split(ctx, desync)` — `lua/zapret-antidpi.lua:254-293` `[evidence: verified]` CLI: `--lua-desync=synack_split[:arg=...]`

## What it does

Six desync functions that do not fit the split/fake/disorder families: a TLS ClientHello cloner (blob preparation), an RST sender, a UDP length mutator, a DHT bencode editor, and two server-side TCP-handshake manipulators.

- **`tls_client_hello_clone`** — prepares a blob (stored in `desync[<blob>]`) holding a modified copy of the current TLS ClientHello, for use as a fake by a later instance. **No traffic effect by itself** — it only fills the blob. Works only on TCP + `tls_client_hello` payload `[evidence: verified]`. **New in nfqws2 — no nfqws1 analog** `[evidence: verified]` (source comment `lua/zapret-antidpi.lua:357`: "nfqws1 : not available").
- **`rst`** — sends an empty TCP packet with `RST` (or `RST+ACK` with `rstack`) as a separate packet. **No verdict** (the original also passes); used to forcibly close a connection. `[evidence: verified]`
- **`udplen`** — increases or decreases the UDP L4 payload length (growth fills with `pattern`; shrink truncates and is lossy). UDP only. `[evidence: verified]`
- **`dht_dn`** — edits the bencode prefix of a DHT message (`d1`/`d2` → `d3` etc.) to evade signature DPI that matches only `d1`/`d2`. Works only on payload type `dht`. `[evidence: verified]`
- **`synack`** — sends a SYN,ACK before the SYN ("TCB turnaround"), confusing DPI about the connection direction. **Breaks NAT** (needs nftables POSTNAT for forwarded traffic). **Server-side, not applicable to the router agent's client-side deployment.** No verdict. `[evidence: verified]` (mechanism); `[evidence: community-observed]` (server-side + NAT-breakage).
- **`synack_split`** — server-side "TCP split handshake": replaces the outgoing SYN,ACK with a SYN, or a SYN+ACK pair, or an ACK+SYN pair. `VERDICT_DROP` on success. **Server-side, not applicable to the router agent's client-side deployment.** `[evidence: verified]` (mechanism); `[evidence: community-observed]` (server-side).

## Arguments (own)

### `tls_client_hello_clone`

| Arg | Type | Default | Notes | Evidence |
|-----|------|---------|-------|----------|
| `direction` | `in`/`out`/`any` | `out` | Standard direction filter. | verified |
| `blob` | name | (required) | Output blob name (stored in `desync[<blob>]`, not global). **Errors if absent.** | verified |
| `fallback` | blob name | none | Copy this blob into the result if the payload is not a valid `tls_client_hello`. | verified |
| `sni_del_ext` | flag | off | Delete the SNI extension entirely (other SNI args ignored). | verified |
| `sni_del` | flag | off | Delete all SNI names. | verified |
| `sni_snt` | value | none | Set `server_name_type` on existing names. | verified |
| `sni_snt_new` | value | none | `server_name_type` for newly added names. | verified |
| `sni_first` | name | none | Add a name at the beginning of the SNI list. | verified |
| `sni_last` | name | none | Add a name at the end of the SNI list. | verified |

SNI operation order: `sni_del_ext` (cancels all other SNI ops) → `sni_del` → `sni_snt` → `sni_first` → `sni_last` `[evidence: verified]`. If an SNI mod is requested but the SNI extension is absent, it is added at the start of the extensions list `[evidence: verified]`.

### `rst`

| Arg | Type | Default | Notes | Evidence |
|-----|------|---------|-------|----------|
| `direction` | `in`/`out`/`any` | `any` | Standard direction filter. | verified |
| `payload` | payload filter | `known` | Standard payload filter (default `known`). | verified |
| `fooling` | fooling flags | none | Standard fooling on the RST packet. | verified |
| `ipid` | ip_id opts | `none` | Standard ipid (default `none`). | verified |
| `ipfrag` | ipfrag opts | none | Standard ipfrag. | verified |
| `reconstruct` | reconstruct opts | none | Standard reconstruct. | verified |
| `rawsend` | rawsend opts | none | Standard rawsend. | verified |
| `rstack` | flag | off | Send `RST+ACK` instead of `RST`. | verified |

### `udplen`

| Arg | Type | Default | Notes | Evidence |
|-----|------|---------|-------|----------|
| `direction` | `in`/`out`/`any` | `out` | Standard direction filter. | verified |
| `payload` | payload filter | `known` | Standard payload filter (default `known`). | verified |
| `min` | number | none | Skip payloads shorter than N. | verified |
| `max` | number | none | Skip payloads longer than N. | verified |
| `increment` | number | `2` | Bytes to add (+) or remove (−). Negative shrinks (lossy). | verified |
| `pattern` | blob | `\x00` | Fill bytes appended on growth. | verified |
| `pattern_offset` | number | `0` | Starting offset inside `pattern`. | verified |

### `dht_dn`

| Arg | Type | Default | Notes | Evidence |
|-----|------|---------|-------|----------|
| `direction` | `in`/`out`/`any` | `out` | Standard direction filter. | verified |
| `dn` | number | `3` | N in the rewritten `dN:` prefix. | verified |

Payload must be `dht` (else silent no-op) `[evidence: verified]`.

### `synack`

| Arg | Type | Default | Notes | Evidence |
|-----|------|---------|-------|----------|
| `ipfrag` | ipfrag opts | none | Standard ipfrag. | verified |
| `reconstruct` | reconstruct opts | none | Standard reconstruct. | verified |
| `rawsend` | rawsend opts | none | Standard rawsend. | verified |

No `direction` — acts on the outgoing SYN. Cutoff after any non-SYN packet `[evidence: verified]`.

### `synack_split`

| Arg | Type | Default | Notes | Evidence |
|-----|------|---------|-------|----------|
| `ipfrag` | ipfrag opts | none | Standard ipfrag. | verified |
| `reconstruct` | reconstruct opts | none | Standard reconstruct. | verified |
| `rawsend` | rawsend opts | none | Standard rawsend. | verified |
| `mode` | `syn`/`synack`/`acksyn` | `synack` | Replacement shape: `syn` = one SYN; `synack` = SYN then ACK; `acksyn` = ACK then SYN. Errors on any other value. | verified |

Acts on the outgoing SYN,ACK (server-side). Cutoff after any non-SYN,ACK packet `[evidence: verified]`.

## Verdict & protocol

| Function | Verdict | Protocol | Evidence |
|----------|---------|----------|----------|
| `tls_client_hello_clone` | none (`VERDICT_PASS` default; blob preparation only) | TCP + `tls_client_hello` only | verified |
| `rst` | none (`VERDICT_PASS` default; original also passes) | TCP | verified |
| `udplen` | `VERDICT_MODIFY` (only when length changed) | UDP only | verified |
| `dht_dn` | `VERDICT_MODIFY` | UDP + payload `dht` only | verified |
| `synack` | none (`VERDICT_PASS` default) | TCP (SYN) | verified |
| `synack_split` | `VERDICT_DROP` on success / `VERDICT_PASS` on rawsend failure | TCP (SYN,ACK) | verified |

## Gotchas

- **`synack` and `synack_split` are server-side** — they manipulate the SYN,ACK the *server* sends, not the client's SYN. The router agent is client-side, so these are **not applicable to the router agent's client-side deployment**; documented for completeness because they appear in upstream presets. `[evidence: community-observed]`
- **`synack` breaks NAT** — sending SYN,ACK before SYN confuses NAT state; on forwarded traffic it requires nftables POSTNAT. Not viable through a typical NAT router. `[evidence: community-observed]`
- **`tls_client_hello_clone` is blob preparation, not a send.** It only fills `desync[<blob>]`; a later `fake:blob=<that name>` (or `send`/`syndata`) must emit it. Without a downstream consumer the clone has no traffic effect. `[evidence: verified]`
- **`tls_client_hello_clone` `blob` is required** (errors if absent) and stored in `desync` (per-connection), not in the global blob table — so it is visible only to later instances in the same profile, not across profiles. `[evidence: verified]`
- **`udplen` shrink is lossy** — a negative `increment` truncates the payload from the end; the dropped bytes are gone. Growth fills with `pattern` (default `\x00`) from `pattern_offset`. `[evidence: verified]`
- **`udplen` will not shrink to zero** — if `len + increment < 1` the function no-ops rather than producing an empty payload. `[evidence: verified]`
- **`udplen` MTU/PMTU**: UDP cannot be segmented; on growth that exceeds MTU the OS IP-fragments (Linux errors, WinDivert/ipdivert silently drop). `[evidence: verified]`
- **`dht_dn` rewrites the bencode prefix** to `d<N>:<N zeros>1:x` followed by the original tail from position 2 — the bencode structure is preserved so a conformant DHT peer still parses it, but a DPI keyed on `d1`/`d2` no longer matches. `[evidence: verified]`
- `rst` only acts on the first replay piece (`replay_first`); on further replay pieces it no-ops to avoid sending multiple RSTs. `[evidence: verified]`

## nfqws1 → nfqws2 migration

| nfqws1 | nfqws2 |
|--------|--------|
| `--dpi-desync=rst` | `--lua-desync=rst[:rstack]` |
| `--dpi-desync=udplen` | `--lua-desync=udplen:increment=…` |
| `--dpi-desync=tamper` (dht) | `--lua-desync=dht_dn:dn=…` |
| `--dpi-desync=synack` | `--lua-desync=synack` (server-side, not applicable to router agent) |
| `--dpi-desync=synack-split` | `--lua-desync=synack_split:mode=…` (server-side, not applicable to router agent) |
| `--dpi-desync=tls_client_hello_clone` | **N/A — new in nfqws2, no nfqws1 analog** (`tls_client_hello_clone`) |

`[evidence: verified]` for the mapping (source comments at each function); `[evidence: community-observed]` for the server-side/NAT caveats.

## Cross-references

`fake` (the consumer of `tls_client_hello_clone`'s blob), `rst`/`send` (separate-packet senders), `udplen`↔`dht_dn` (UDP mutators), `wssize` (the other window/syn-ack-family function), `orchestrators.md` (`rst` as a rotation reset trigger is owned by `circular`'s failure detector, not this function). Full migration: `../migration.md`; fooling-flag syntax: `zapret2-engine-reference`.

## Source mapping

Upstream code: `lua/zapret-antidpi.lua:367-389` (`tls_client_hello_clone`), `:421-442` (`rst`), `:1198-1230` (`udplen`), `:1235-1250` (`dht_dn`), `:297-311` (`synack`), `:254-293` (`synack_split`).
