# detect_payload_str — content-based payload-type detector

## Lua signature

`function detect_payload_str(ctx, desync)` — `lua/zapret-lib.lua:94-107` `[evidence: verified]` CLI: `--lua-desync=detect_payload_str:pattern=<str>[:payload=<type>[:undetected=<type>]]`

## What it does

Substring detector: searches `desync.reasm_data` (or `desync.dis.payload`) for `pattern`; on a match it sets `desync.l7payload = <payload>`, on a miss it sets `desync.l7payload = <undetected>` (if given). This lets the agent define a custom payload type *by content* and then filter subsequent instances with `:payload=<that type>` `[evidence: verified]`. Use case: recognising a non-standard protocol marker the C code does not know about, so a later `fake`/`send` instance gated on `:payload=my` only fires for that protocol `[evidence: community-observed]` (use case from upstream manual example).

## Arguments (own)

| Arg | Type | Default | Notes | Evidence |
|-----|------|---------|-------|----------|
| `pattern` | string | (required) | Substring to search for (plain `string.find`, no pattern). **Errors if absent.** | verified |
| `payload` | payload type | none | Value assigned to `desync.l7payload` on detection. | verified |
| `undetected` | payload type | none | Value assigned to `desync.l7payload` on non-detection (only set if present). | verified |

## Verdict & protocol

- Verdict: none returned (`VERDICT_PASS` default) — it only sets `desync.l7payload`; no traffic effect on its own `[evidence: verified]`.
- Protocol: any (searches whatever payload is present).

## Gotchas

- **The C code does not see this payload type.** `desync.l7payload` is a Lua-side field; `--payload=<custom>` on the command line is rejected by the C code (it only knows built-in types). The custom type is usable only as a `:payload=` filter on subsequent Lua desync instances, not as a top-level `--payload`. `[evidence: verified]`
- Searches `reasm_data` if present, else `dis.payload` — for multi-packet requests the reassembled buffer is checked, so the marker can span original packet boundaries. `[evidence: verified]`
- `pattern` is matched with `string.find(...,1,true)` (plain text, no Lua pattern metacharacters) — a `pattern` containing `%` or `.` is matched literally. `[evidence: verified]`
- Pair with `condition`/`cond_payload_str` in `orchestrators.md` if you want conditional execution rather than a payload-type label. `[evidence: community-observed]`

## nfqws1 → nfqws2 migration

**New in nfqws2 — no nfqws1 analog.** nfqws1 could not define custom payload types by content; `detect_payload_str` is nfqws2-only `[evidence: verified]`.

## Cross-references

`luaexec` (same `zapret-lib.lua` base-function family; arbitrary code for richer detection), `orchestrators.md` (`cond_payload_str` — the iff predicate counterpart), `fake`/`send` (instances gated on the custom `:payload=`). Full migration: `../migration.md`.

## Source mapping

Upstream code: `lua/zapret-lib.lua:94-107` (`detect_payload_str`). (Lives in the library file, not `zapret-antidpi.lua` — base functions shipped in `zapret-lib.lua`.)
