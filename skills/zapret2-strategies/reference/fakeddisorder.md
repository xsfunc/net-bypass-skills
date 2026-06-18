# fakeddisorder — reverse-order split + fakes (triple confusion)

## Lua signature

`function fakeddisorder(ctx, desync)` — `lua/zapret-antidpi.lua:908-1021` `[evidence: verified]` CLI: `--lua-desync=fakeddisorder[:arg=...]`

## What it does

Triple confusion: split + fakes + reverse order. Cuts the payload at **one** position into 2 parts, surrounds each with fakes, and sends in **reverse order** (part 2 first). Sends 6 packets: fakeP2, realP2(+seqovl), fakeP2', fakeP1, realP1, fakeP1'. Returns `VERDICT_DROP` `[evidence: verified]`. The most aggressive single-technique strategy in the ladder; use when DPI checks both order and content.

## DPI-capability selection table `[evidence: hypothesis]`

| DPI behavior | Use |
|--------------|-----|
| Does not reassemble | `multisplit` |
| Reassembles, no order check | `multidisorder` |
| Checks order, not content | `fakedsplit` |
| Checks both order and content | `fakeddisorder` |

(This table is a reasoning heuristic from the source, not code-confirmed — treat as report-and-ask.)

## Arguments (own)

| Arg | Type | Default | Notes | Evidence |
|-----|------|---------|-------|----------|
| `pos` | ONE marker | `"2"` | Single marker only (`resolve_pos`). `pos=midsld,endhost` invalid. `pos=1` → "cannot split", no-op. | verified |
| `seqovl` | **marker** | none | **A MARKER** (like `multidisorder`, unlike `fakedsplit`). Resolved via `resolve_pos`, then `-1` (Lua→0-based); must be **< `pos-1`** else cancelled. Targets the **2nd real segment** (first real sent). | verified |
| `seqovl_pattern` | blob | none | Fake bytes for the overlap. | verified |
| `pattern` | blob | `\x00` | Fake fill bytes. | verified |
| `blob` | name/hex | (data) | Override payload source. | verified |
| `nofake1`..`nofake4` | flag | off | Suppress specific fakes. | verified |
| `optional` | flag | off | Silent skip if blob missing. | verified |
| `nodrop` | flag | off | `VERDICT_PASS` (debug). | verified |

Fooling/reconstruct/repeats **only on fakes**; `tcp_ts_up` on both. **ipfrag NOT supported.**

## Verdict & protocol

- Verdict: `VERDICT_DROP` (unless `nodrop`) `[evidence: verified]`.
- Protocol: TCP only.

## Gotchas

- **Fooling mandatory for fakes** (else server accepts fakes as real data). `[evidence: verified]`
- `pos=1` → "cannot split", no-op; single marker only. `[evidence: verified]`
- seqovl is a **marker** here (contrast `fakedsplit`: number-only); targets the 2nd real segment via buffer-overwrite. **Windows-server seqovl limitation applies** (buffer overwrite fails on Windows). `[evidence: verified]`
- `tcp_ts_up` recommended with `tcp_ack` (Linux timestamp-first rule). `[evidence: verified]`

## nfqws1 → nfqws2 migration

| nfqws1 | nfqws2 |
|--------|--------|
| `--dpi-desync=fakeddisorder` | `--lua-desync=fakeddisorder` |
| `--dpi-desync-fooling=badseq` | `:tcp_ack=-66000:tcp_ts_up` |
| `--dpi-desync-split-pos=…` | `:pos=<single marker>` |
| `--dpi-desync-split-seqovl=…` | `:seqovl=<marker>` — **new: marker allowed** |
| fooling flags | see `migration.md` |

## Cross-references

`fakedsplit` (forward order, number seqovl), `multisplit`/`multidisorder`, `hostfakesplit`, `tcpseg`, `oob`. Full migration + marker table: `../migration.md`.

## Source mapping

Upstream code: `lua/zapret-antidpi.lua:908-1021`.
