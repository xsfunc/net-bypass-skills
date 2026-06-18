# tcpseg — range segmentation, no verdict (new in nfqws2)

## Lua signature

`function tcpseg(ctx, desync)` — `lua/zapret-antidpi.lua:1030-1076` (`resolve_range` in `nfq2/lua.c:3281-3328`) `[evidence: verified]` CLI: `--lua-desync=tcpseg[:arg=...]`

## What it does

Sends a **range** of the current payload (or reasm, or blob) — bounded by **exactly two** position markers — as a single TCP segment. Unlike `multisplit`, which cuts the whole payload into many segments at a list of points, `tcpseg` cuts out one specific range and **returns no verdict**. To replace the original packet, combine with a separate `drop` instance `[evidence: verified]`. **New in nfqws2 — no nfqws1 equivalent.**

## Primary use cases

1. **seqovl without segmentation:** `pos=0,-1` (whole payload) + seqovl prefix that overwrites the stream start for DPI, no cutting. `[evidence: verified]`
2. **Repeat-send the stream start:** `repeats=N` without `drop` floods the DPI buffer (e.g. `pos=0,method+2`). `[evidence: verified]`
3. **Modular composition:** combine with `drop`/`luaexec` for custom verdict logic. `[evidence: verified]`

## Arguments (own)

| Arg | Type | Default | Notes | Evidence |
|-----|------|---------|-------|----------|
| `pos` | marker1,marker2 | (required) | **Exactly 2 markers = a range** via `resolve_range` (non-strict). Errors if missing/wrong count. `pos=0,-1` = whole payload; `pos=host,endhost` = hostname only. Marker `0` is a valid start (unlike `multisplit` which deletes pos 1). | verified |
| `seqovl` | number | none | **NUMBER ONLY**. Supports `seqovl=#rnd` (C-substitution of blob length) and dynamic blobs via `luaexec`. | verified |
| `seqovl_pattern` | blob | none | Fake prefix bytes. | verified |
| `blob` | name/hex | (data) | Override payload source. | verified |
| `optional` | flag | off | Silent skip if blob missing. | verified |

**NO `nodrop`** (no verdict to suppress). Standard sections A–H; fooling applies to the **real segment** (caution — `tcp_ack=-66000` makes the server drop it); safe fooling: `ip_id`, `tcp_ts_up`, IPv6 headers. ipfrag supported.

## Verdict & protocol

- Verdict: **none** — original passes unless combined with `drop`: `--lua-desync=tcpseg:... --lua-desync=drop`. `drop` defaults to `payload=all`; to match tcpseg's `known` use `--lua-desync=drop:payload=known`. `[evidence: verified]`
- Protocol: TCP only.

## Gotchas

- **No verdict** — without a `drop` instance both the segment and the original leave; with `drop` the original is replaced. `[evidence: verified]`
- `resolve_range` is **non-strict**: one unresolved marker → expands to the data boundary (0 or len-1); both unresolved → `nil` (no-op). `[evidence: verified]`
- `pos=0,-1` is the canonical "whole payload + seqovl, no cut" pattern. `[evidence: verified]`
- Fooling targets the **real** segment here (unlike fake-family where fooling targets fakes) — destructive fooling drops real data. `[evidence: verified]`

## nfqws1 → nfqws2 migration

**N/A — new in nfqws2, no nfqws1 equivalent.** (Closest nfqws1 concept is `--dpi-desync=split` with a single range, but the no-verdict + `drop` composition is nfqws2-only.) `[evidence: verified]`

## Cross-references

`multisplit`/`multidisorder` (full cuts with verdict), `fakedsplit`/ `fakeddisorder`, `hostfakesplit`, `oob`. Full migration + marker table: `../migration.md`. Foundation of testing-ladder rung 1: `../testing-ladder.md`.

## Source mapping

Upstream code: `lua/zapret-antidpi.lua:1030-1076`; `resolve_range` in `nfq2/lua.c:3281-3328`.
