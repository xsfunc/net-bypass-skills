# multisplit — forward-order multi-point split

## Lua signature

`function multisplit(ctx, desync)` — `lua/zapret-antidpi.lua:471` `[evidence: verified]` CLI: `--lua-desync=multisplit[:arg=...]`

## What it does

The basic TCP segmentation function: cuts the current payload (or reasm, or blob) into several TCP segments at the given positions and sends them in **forward order** (first to last). Returns `VERDICT_DROP` so the original does not also leave `[evidence: verified]`. DPI that does not reassemble is fooled by the split; DPI that reassembles but ignores order is not — escalate to `multidisorder`.

## Arguments (own)

| Arg | Type | Default | Notes | Evidence |
|-----|------|---------|-------|----------|
| `pos` | list | `"2"` | Split points via `resolve_multi_pos`. **Position 1 is auto-deleted** — `pos=1` alone makes no cut (use `pos=2`). Duplicates merged, unresolved markers silently dropped, sorted. | verified |
| `seqovl` | number | none | Sequence overlap — **NUMBER ONLY** (not a marker here). Hidden fake injected into the **first** segment via the TCP window boundary (bytes left of the server window are discarded). `10000` is fine (auto MSS-segmentation, unlike nfqws1). | verified |
| `seqovl_pattern` | blob | none | Bytes for the seqovl fake prefix. | verified |
| `blob` | name/hex | (data) | Override payload source; markers like `midsld` only resolve if the blob is a valid TLS/HTTP payload. | verified |
| `optional` | flag | off | Silent skip if blob missing. | verified |
| `nodrop` | flag | off | Return `VERDICT_PASS` instead of `DROP` (original also sent — debug only; causes duplication). | verified |

Standard sections: A) direction, B) payload filter, C) fooling (**applies to ALL segments** — caution), D) ipid, E) ipfrag (supported), F) reconstruct, G) rawsend.

## Position markers

`method`, `host`, `endhost`, `sld`, `endsld`, `midsld`, `sniext`, `extlen` plus arithmetic `marker+N`/`marker-N`; absolute `N`, `-N` from end `[evidence: verified]`. Full marker table: `../migration.md`.

## Verdict & protocol

- Verdict: `VERDICT_DROP` (unless `nodrop`) `[evidence: verified]`.
- Protocol: TCP only (UDP/ICMP → `instance_cutoff`).

## Gotchas

- **Position 1 is deleted** → `pos=1` makes no cut; default `pos=2` splits off the first byte. `[evidence: verified]`
- **Fooling hits ALL segments** here (unlike fake-family where fooling targets fakes only). `tcp_ack=-66000` breaks every segment — use only safe fooling (`tcp_ts_up`, `ip_id`, IPv6 headers) with multisplit. `[evidence: verified]`
- seqovl is **number-only** here (contrast `multidisorder`/`fakeddisorder`, which accept markers) and targets the **first** segment via the TCP-window mechanism. `[evidence: verified]`
- Data source priority: `blob_or_def()` → `reasm_data` → `dis.payload`. `[evidence: verified]`

## nfqws1 → nfqws2 migration

| nfqws1 | nfqws2 |
|--------|--------|
| `--dpi-desync=split` | `--lua-desync=multisplit` |
| `--dpi-desync-split-pos=1,midsld` | `:pos=1,midsld` |
| `--dpi-desync-split-seqovl=5` | `:seqovl=5` |
| `--dpi-desync-split-seqovl-pattern=0x...` | `:seqovl_pattern=0x...` |
| fooling flags | see `migration.md` |

## Cross-references

`multidisorder` (reverse order), `fakedsplit`/`fakeddisorder` (fakes around splits), `hostfakesplit` (hostname-bound), `tcpseg` (range, no verdict), `oob`. Full migration + marker table: `../migration.md`.

## Source mapping

Upstream code: `lua/zapret-antidpi.lua:471-…`.
