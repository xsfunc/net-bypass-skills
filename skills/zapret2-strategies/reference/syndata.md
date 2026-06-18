# syndata — SYN-phase payload injection

## Lua signature

`function syndata(ctx, desync)` — `lua/zapret-antidpi.lua:385` `[evidence: verified]` CLI: `--lua-desync=syndata[:arg=...]`

## What it does

The "phase 0" strategy: injects an arbitrary payload into the TCP SYN, applies mods/fooling, and sends it **instead of** the original SYN. The original is dropped (`VERDICT_DROP`). It runs *before* the connection is established — at the moment the client emits the SYN `[evidence: verified]`.

## Arguments (own)

| Arg | Type | Default | Notes | Evidence |
|-----|------|---------|-------|----------|
| `blob` | name/hex | 16 null bytes | Payload added to SYN. **Not required** (defaults to 16 null bytes, unlike `fake`). Must fit one packet — TCP segmentation impossible (`rawsend_dissect_ipfrag`, not `rawsend_payload_segmented`). | verified |
| `tls_mod` | list | none | `rnd`/`rndsni`/`sni=` work. **`dupsid` and `padencap` are silently ignored** (no real payload exists at SYN). | verified |

**Does NOT support:** `dir`, `payload` filter, `ipid` (phase-0 constraints). Fooling is destructive on the handshake — see gotchas.

## Verdict & protocol

- Verdict: `VERDICT_DROP` (replaces the SYN) `[evidence: verified]`.
- Protocol: TCP only (SYN is TCP).

## Gotchas

- **Phase 0 limits:** no real payload, no hostname, no payload filter at SYN time. Hostlists work only via `--ipcache-hostname` — the *first* connection to an IP is not affected. `[evidence: verified]`
- **Destructive fooling breaks the handshake:** `tcp_seq`/`tcp_ack`/`badsum`/ `tcp_flags_unset=SYN` make the server reject the SYN. Safe fooling: `tcp_md5`, `tcp_ts_up`, `tcp_nop_del`, IPv6 extension headers. `[evidence: verified]`
- `tls_mod=dupsid`/`padencap` silently ignored (no payload to act on). `[evidence: verified]`
- **Instance order matters:** `wssize` must come *before* `syndata`, else wssize sees `VERDICT_DROP` and never gets the SYN. nfqws1 `--wssize 1:6` → a separate `--lua-desync=wssize:wsize=1:scale=6` instance placed before syndata. `[evidence: verified]`
- Processes every SYN retransmission; `instance_cutoff` on non-SYN; ICMP does not trigger cutoff. `[evidence: verified]`

## nfqws1 → nfqws2 migration

| nfqws1 | nfqws2 |
|--------|--------|
| `--dpi-desync=syndata` | `--lua-desync=syndata[:blob=...]` |
| `--wssize 1:6` | separate `--lua-desync=wssize:wsize=1:scale=6` **before** syndata |
| fooling flags | see `migration.md` |

## Cross-references

`fake` (data-phase, no verdict), `multisplit`/`multidisorder` (post-SYN split), `wssize` (must precede syndata). Full fooling-flag migration: `../migration.md`.

## Source mapping

Upstream code: `lua/zapret-antidpi.lua:385-437`.
