# multidisorder_legacy — per-packet nfqws1-compatible disorder

## Lua signature

`function multidisorder_legacy(ctx, desync)` — `lua/zapret-antidpi.lua:530-684` `[evidence: verified]` CLI: `--lua-desync=multidisorder_legacy[:arg=...]`

## What it does

The 100%-nfqws1-compatible variant of disorder. The key difference from the new `multidisorder`: it processes **per-packet** (current `dis.payload`) for cutting and uses `reasm_data` (fulldata) only for marker resolution, whereas the new one operates on the whole reasm at once. Reverse order applies **inside each packet**; between packets the order is forward. Original segmentation (e.g. 500+300) is preserved `[evidence: verified]`. For single-packet payloads it is identical to the new `multidisorder`.

## When to choose legacy vs new

- Need **100% nfqws1 behavior** for migrating an existing `--dpi-desync=disorder` preset → use `multidisorder_legacy`.
- Need the new whole-reasm algorithm, `blob`, or `nodrop` → use `multidisorder`.
- Single-packet payload → both are identical; prefer the new one `[evidence: verified]`.

## Arguments (own)

| Arg | Type | Default | Notes | Evidence |
|-----|------|---------|-------|----------|
| `pos` | list | `"2"` | Per-packet positions, normalized via `pos_array_normalize(pos, range_low, range_hi)`. Out-of-range positions **deleted**. `delete_pos_1` runs **after** normalization. | verified |
| `seqovl` | **marker** | none | Marker resolved on fulldata, then normalized per-packet. May apply to different packets across scenarios; may cancel for all packets if on a boundary. | verified |
| `seqovl_pattern` | blob | none | Fake bytes for the per-packet overlap. | verified |
| `optional` | flag | off | Silent skip if blob missing. | verified |

**NO `blob`, NO `nodrop`** (key differences from the new `multidisorder`). Standard sections A–G; fooling on ALL segments; ipfrag supported.

## Verdict & protocol

- Verdict: `VERDICT_DROP` `[evidence: verified]`.
- Protocol: TCP only.
- **No `replay_first`/`replay_drop`** — called for every replay packet (this IS the per-packet design). `[evidence: verified]`

## Gotchas

- Per-packet normalization: a position that falls outside the current packet's range is deleted, not clamped. `[evidence: verified]`
- Reverse order is per-packet only; across packets order is forward, so the original multi-packet segmentation is preserved. `[evidence: verified]`
- A packet with no remaining positions is sent as-is via `rawsend_payload_segmented` (fooling/ipid still applied). `[evidence: verified]`
- **Windows-server seqovl limitation applies** (same as `multidisorder`): buffer-overwrite seqovl fails on Windows servers. `[evidence: verified]`

## nfqws1 → nfqws2 migration

This IS the migration target for nfqws1 `--dpi-desync=disorder` when 100% compat is required `[evidence: verified]`. Map `--dpi-desync-split-pos` → `:pos`, `--dpi-desync-split-seqovl` → `:seqovl=<marker>` (new: marker allowed), fooling per `migration.md`. When migrating from the *new* `multidisorder` back to legacy, drop `blob` and `nodrop` (unsupported here).

## Cross-references

`multidisorder` (new, whole-reasm), `multisplit`, `fakedsplit`/`fakeddisorder`. Full migration + marker table: `../migration.md`.

## Source mapping

Upstream code: `lua/zapret-antidpi.lua:530-684` (footer range; header line mismatch is a source artifact).
