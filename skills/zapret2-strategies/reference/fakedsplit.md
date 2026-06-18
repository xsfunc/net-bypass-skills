# fakedsplit — split surrounded by same-seq fakes (6 packets)

## Lua signature

`function fakedsplit(ctx, desync)` — `lua/zapret-antidpi.lua:803-906` `[evidence: verified]` CLI: `--lua-desync=fakedsplit[:arg=...]`

## What it does

Cuts the payload at **one** position into 2 parts and surrounds each real part with fake segments of the same size and the same TCP seq, so DPI sees what looks like retransmissions. Sends up to **6 packets**: fake1, real1(+seqovl), fake1', fake2, real2, fake2'. Returns `VERDICT_DROP` `[evidence: verified]`. Use when DPI checks segment order but not content; if it checks both, escalate to `fakeddisorder`.

## Arguments (own)

| Arg | Type | Default | Notes | Evidence |
|-----|------|---------|-------|----------|
| `pos` | ONE marker | `"2"` | **Single marker only** — `resolve_pos`, NOT a list. `pos=midsld,endhost` does NOT work (comma not parsed). `pos=1` → "cannot split", no-op. Unresolved → no-op. | verified |
| `pattern` | blob | `\x00` | Bytes filling the fakes. | verified |
| `seqovl` | number | none | **NUMBER ONLY** (contrast `fakeddisorder` = marker). Hidden fake in the **first real segment** (packet #2) via the TCP-window mechanism. | verified |
| `seqovl_pattern` | blob | none | seqovl fake prefix. | verified |
| `blob` | name/hex | (data) | Override payload source. | verified |
| `optional` | flag | off | Silent skip if blob missing. | verified |
| `nodrop` | flag | off | `VERDICT_PASS` (debug; duplication). | verified |
| `nofake1`..`nofake4` | flag | off | Suppress specific fake packets. | verified |

**Two opts sets:** `opts_orig` (only `tcp_ts_up`, no repeats, no badsum, empty ipfrag) vs `opts_fake` (full fooling, repeats, badsum, empty ipfrag). Fooling / reconstruct / repeats apply **only to fakes**; `tcp_ts_up` on both. **ipfrag NOT supported** (both opts have `ipfrag={}`).

## Position markers

Single marker from the standard set (`method`, `host`, `sld`, `midsld`, `sniext`, `extlen`, arithmetic). Full table: `../migration.md`.

## Verdict & protocol

- Verdict: `VERDICT_DROP` (unless `nodrop`) `[evidence: verified]`.
- Protocol: TCP only.

## Gotchas

- **Fooling mandatory for fakes** — without it the server accepts fakes as real data and the stream breaks. `[evidence: verified]`
- `pos=1` → "cannot split", no-op; default `pos=2`. Single marker only. `[evidence: verified]`
- `tcp_ts_up` recommended with `tcp_ack` (Linux drops bad-ack packets unless the TCP timestamp option is first in the header). `[evidence: verified]`
- seqovl is **number-only** here and targets the 1st real segment (contrast `fakeddisorder`: marker, 2nd real segment). `[evidence: verified]`
- ipfrag not supported at all. `[evidence: verified]`

## nfqws1 → nfqws2 migration

| nfqws1 | nfqws2 |
|--------|--------|
| `--dpi-desync=fakedsplit` | `--lua-desync=fakedsplit` |
| `--dpi-desync-fooling=badseq` | `:tcp_ack=-66000:tcp_ts_up` |
| `--dpi-desync-split-pos=…` | `:pos=<single marker>` |
| `--dpi-desync-split-seqovl=…` | `:seqovl=<number>` |
| fooling flags | see `migration.md` |

## Cross-references

`fakeddisorder` (reverse order + marker seqovl), `multisplit`/`multidisorder`, `hostfakesplit`, `tcpseg`, `oob`. Full migration + marker table: `../migration.md`.

## Source mapping

Upstream code: `lua/zapret-antidpi.lua:803-906`.
