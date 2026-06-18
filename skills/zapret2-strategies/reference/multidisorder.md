# multidisorder — reverse-order split + buffer-overwrite seqovl

## Lua signature

`function multidisorder(ctx, desync)` — `lua/zapret-antidpi.lua:546-629` `[evidence: verified]` CLI: `--lua-desync=multidisorder[:arg=...]`

## What it does

Cuts the payload into segments at the given positions and sends them in **reverse order** (last to first). Disorder exploits TCP-stack behavior: the stack buffers out-of-order segments and reassembles, while DPI often fails to reassemble disordered data. Returns `VERDICT_DROP` `[evidence: verified]`. Use when DPI reassembles but does not check order; if it checks both order and content, escalate to `fakedsplit`/`fakeddisorder`.

## Arguments (own)

| Arg | Type | Default | Notes | Evidence |
|-----|------|---------|-------|----------|
| `pos` | list | `"2"` | Split points via `resolve_multi_pos`. Position 1 auto-deleted, merged, sorted. | verified |
| `seqovl` | **marker** | none | **A MARKER, not just a number** (resolved via `resolve_pos`): `seqovl=midsld-1`, `seqovl=host+2`, `seqovl=5`. Unresolved → seqovl cancelled but split still happens. | verified |
| `seqovl_pattern` | blob | none | Fake bytes written into the socket buffer, later overwritten by the real segment. | verified |
| `blob` | name/hex | (data) | Override payload source. | verified |
| `optional` | flag | off | Silent skip if blob missing. | verified |
| `nodrop` | flag | off | `VERDICT_PASS` instead of `DROP` (debug). | verified |

Standard sections A–G; fooling applies to **ALL segments**; ipfrag supported.

## Position markers

Same set as `multisplit` (`method`, `host`, `endhost`, `sld`, `endsld`, `midsld`, `sniext`, `extlen`, arithmetic). Full table: `../migration.md`.

## Verdict & protocol

- Verdict: `VERDICT_DROP` (unless `nodrop`) `[evidence: verified]`.
- Protocol: TCP only.

## Gotchas

- **seqovl does NOT work on Windows servers.** Windows keeps the first-received data and does not overwrite the socket buffer on overlapping segments; the `seqovl_pattern` written by the penultimate segment is NOT overwritten by the last → the server gets garbage. Linux/BSD/macOS overwrite correctly. **Without seqovl**, plain disorder works on all OSes. `[evidence: verified]`
- **seqovl validation:** resolved marker must be strictly **< `pos[1]`** else cancelled. Real overlap size is `ovl = seqovl - 1` (1-based→0-based); minimal effective seqovl = 2 (ovl=1). `[evidence: verified]`
- seqovl targets segment `i==1` (2nd in original order = **penultimate sent**) via buffer-overwrite (not the TCP-window mechanism used by `multisplit`). `[evidence: verified]`
- Algorithm is "not 100% same as nfqws1" for multi-segment queries (uses whole reasm). For 100% nfqws1 compat use `multidisorder_legacy`. `[evidence: verified]`
- Fooling hits ALL segments (same caution as `multisplit`). `[evidence: verified]`

## nfqws1 → nfqws2 migration

| nfqws1 | nfqws2 |
|--------|--------|
| `--dpi-desync=disorder` | `--lua-desync=multidisorder` |
| `--dpi-desync-split-pos=…` | `:pos=…` |
| `--dpi-desync-split-seqovl=5` (number) | `:seqovl=<marker or number>` — **new: marker allowed** |
| fooling flags | see `migration.md` |

New nfqws2 capability: `seqovl` may now be a marker `[evidence: verified]`.

## Cross-references

`multisplit` (forward order, number-only seqovl), `multidisorder_legacy` (per-packet nfqws1-compat), `fakedsplit`/`fakeddisorder`, `hostfakesplit`, `tcpseg`, `oob`. Full migration + marker table: `../migration.md`.

## Source mapping

Upstream code: `lua/zapret-antidpi.lua:546-629` (header line mismatch with footer is a source artifact; footer range cited here).
