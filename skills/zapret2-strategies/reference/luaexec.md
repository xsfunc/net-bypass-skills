# luaexec — run arbitrary Lua per packet

## Lua signature

`function luaexec(ctx, desync)` — `lua/zapret-lib.lua:17-37` `[evidence: verified]` CLI: `--lua-desync=luaexec:code="<lua source>"`

## What it does

Executes arbitrary Lua supplied in the `code` argument, with `desync` temporarily assigned to a global variable so the code can read/modify it (`desync.rnd=brandom(math.random(5,10))`, custom verdict logic, conditional blob preparation). After the code runs, the global `desync` is cleared `[evidence: verified]`. It is the escape hatch for dynamic behaviour the built-in techniques do not cover: dynamic blob generation, conditional cutoff, custom verdicts, feeding a prepared blob to a later instance `[evidence: community-observed]` (use cases from upstream manual/examples).

## Arguments (own)

| Arg | Type | Default | Notes | Evidence |
|-----|------|---------|-------|----------|
| `code` | Lua string | (required) | Lua source to execute. `desync` is global during execution. **Errors if absent.** | verified |

No standard direction/payload/fooling sections — `luaexec` runs your code, your code does the work `[evidence: verified]`.

## Verdict & protocol

- Verdict: none returned (`VERDICT_PASS` default) — the executed code's return value is discarded by `pcall`; the code must mutate `desync` or call a sender to affect traffic `[evidence: verified]`.
- Protocol: any (the code decides).

## Gotchas

- **`%`/`#`\` substitution is NOT applied** to `code`. The `code` string is loaded verbatim via `load(desync.arg.code, fname)`, so it can safely reference conditionally-created blobs through `desync.arg.<name>` / `desync.<blob>` without the C dereferencer rewriting `%`/`#`\` placeholders. `[evidence: verified]`
- The code is compiled once per instance and cached in `_G[<instance>_code]`; subsequent packets reuse the compiled function. A syntax error in `code` errors at first execution. `[evidence: verified]`
- `desync` is set global only for the duration of the `pcall` and cleared after — do not assume it persists across instances; pass data through `desync.arg`/`desync.<name>`/`desync.track.lua_state`. `[evidence: verified]`
- Errors inside the code propagate via `error()` (the `pcall` re-raises), which the engine surfaces — guard risky logic yourself. `[evidence: verified]`

## nfqws1 → nfqws2 migration

**New in nfqws2 — no nfqws1 analog.** nfqws1 had no per-packet Lua hook; dynamic blob generation and custom verdict logic are nfqws2-only via `luaexec` `[evidence: verified]`.

## Cross-references

`detect-payload-str.md` (content-based payload-type detector), `send`/`pktmod` (what `luaexec`-prepared blobs feed into), `orchestrators.md` (`cond_lua` uses the same `load`+`pcall` pattern with `cond_code`). Full migration: `../migration.md`.

## Source mapping

Upstream code: `lua/zapret-lib.lua:17-37` (`luaexec`). (Lives in the library file, not `zapret-antidpi.lua` — `luaexec`/`detect_payload_str` are base functions shipped in `zapret-lib.lua`.)
