# repeater / condition / per_instance_condition / stopif — orchestrators + iff functions

## Lua signatures

`function repeater(ctx, desync)` — `lua/zapret-auto.lua:525-577` `[evidence: verified]` CLI: `--lua-desync=repeater[:arg=...]`

`function condition(ctx, desync)` — `lua/zapret-auto.lua:451-464` `[evidence: verified]` CLI: `--lua-desync=condition[:arg=...]`

`function per_instance_condition(ctx, desync)` — `lua/zapret-auto.lua:469-498` `[evidence: verified]` CLI: `--lua-desync=per_instance_condition[:arg=...]`

`function stopif(ctx, desync)` — `lua/zapret-auto.lua:505-515` `[evidence: verified]` CLI: `--lua-desync=stopif[:arg=...]`

## What it does

Four `zapret-auto.lua` orchestrators (beyond `circular`, which has its own card). Like `circular`, each calls `orchestrate()` to take over the normal C execution loop and drive the remaining instance plan themselves — deciding which subsequent instances run, how many times, or whether to clear the plan entirely `[evidence: verified]`. They separate control flow from the action functions so you can express multi-strategy logic without patching the desync functions.

- **`repeater`** — repeats the next `instances` instances `repeats` times in the sequence `1-2-3-1-2-3…`, then runs the rest once (unless `stop`/`clear`). Nestable. `[evidence: verified]`
- **`condition`** — runs `iff`; if `iff xor neg` is true, runs the next `instances` (or all remaining); else clears them. `[evidence: verified]`
- **`per_instance_condition`** — runs each of the next `instances` only if that instance has a `cond` (iff function) arg returning true; `cond_neg` inverts per-instance. `[evidence: verified]`
- **`stopif`** — runs `iff`; if `iff xor neg` is true, clears the whole plan (stops further execution). Useful as a nested orchestrator inside `circular` to halt rotation on a condition. `[evidence: verified]`

## Arguments (own)

### `repeater`

| Arg | Type | Default | Notes | Evidence |
|-----|------|---------|-------|----------|
| `instances` | number | `1` | How many of the following instances to repeat. Clamped to the plan size. | verified |
| `repeats` | number | (required) | Number of repeat rounds. **Errors if absent.** | verified |
| `stop` | flag | off | Do not replay the remaining plan after the repeated instances. | verified |
| `clear` | flag | off | Clear the execution plan after the repeated instances (for upstream-orchestrator interaction). | verified |
| `iff` | iff name | `cond_true` | Condition function to continue the repeat loop; if `iff xor neg` is false, the loop breaks. | verified |
| `neg` | flag | off | Invert `iff`. | verified |

### `condition`

| Arg | Type | Default | Notes | Evidence |
|-----|------|---------|-------|----------|
| `iff` | iff name | (required) | Condition function. **Errors if absent/invalid.** | verified |
| `neg` | flag | off | Invert `iff`. | verified |
| `instances` | number | all | How many of the following instances to run conditionally. | verified |

### `per_instance_condition`

| Arg | Type | Default | Notes | Evidence |
|-----|------|---------|-------|----------|
| `instances` | number | all | How many of the following instances to gate on their own `cond`/`cond_neg` args. | verified |

Per-instance args (on each *subordinate* instance, not on `per_instance_condition` itself): `cond` (iff function name, required for the instance to run) and `cond_neg` (invert) `[evidence: verified]`.

### `stopif`

| Arg | Type | Default | Notes | Evidence |
|-----|------|---------|-------|----------|
| `iff` | iff name | (required) | Condition function. **Errors if absent/invalid.** | verified |
| `neg` | flag | off | Invert `iff`. | verified |

## iff functions (condition predicates)

iff functions take `desync` and return a boolean. They are referenced by name in `iff=`/`cond=` args `[evidence: verified]`.

| Function | Arg | Default | Notes | Evidence |
|----------|-----|---------|-------|----------|
| `cond_true` | — | — | Always true. | verified |
| `cond_false` | — | — | Always false. | verified |
| `cond_random` | `percent` | `50` | True with the given probability (0–99). | verified |
| `cond_payload_str` | `pattern` | (required) | True if `pattern` is a substring of `desync.dis.payload`. **Errors if `pattern` absent.** | verified |
| `cond_tcp_has_ts` | — | — | True if the dissect is TCP and the timestamp TCP option is present. (The upstream manual prints this as `cond_tcp_ts`; the callable function is `cond_tcp_has_ts`.) | verified |
| `cond_lua` | `cond_code` | (required) | Run Lua in `cond_code`; return its value. `desync` is global during the call. **`%`/`#`\` are NOT dereferenced** in `cond_code` (it may reference conditionally-created blobs). **Errors if `cond_code` absent.** | verified |

## Verdict & protocol

- `repeater` / `condition` / `per_instance_condition` aggregate verdicts from the instances they run (`verdict_aggregate`) `[evidence: verified]`.
- `stopif` returns no verdict itself — it only clears (or preserves) the plan for the upstream orchestrator `[evidence: verified]`.
- Protocol: any — orchestrators are protocol-agnostic; the instances they run carry the protocol constraints.

## Gotchas

- **Orchestrators are new in nfqws2 — no nfqws1 analog.** nfqws1 had no Lua orchestrator and no conditional/repeat control flow; `circular`/`repeater`/`condition`/`per_instance_condition`/`stopif` are all nfqws2-only and take over the C execution loop via `orchestrate()`. `[evidence: verified]`
- **`repeater` is nestable.** A `repeater` inside a `repeater` works; `stop` on an inner repeater prevents that inner loop from running instances outside its own `instances` window, while the outer repeater still proceeds to its tail instances. `[evidence: verified]`
- **`condition` knows nothing about `circular`'s `strategy=` tags** — it clears the next `instances` blindly. To stop a `circular` rotation on a condition, use `stopif` (which clears the whole plan and thus halts the upstream `circular`), not `condition`. `[evidence: verified]` (source comment `lua/zapret-auto.lua:500-501, 744-745`).
- **`per_instance_condition` uses `cond`/`cond_neg`, not `iff`/`neg`**, to avoid colliding with other orchestrators' args on the same subordinate instance. A subordinate without a `cond` arg is skipped (not run unconditionally). `[evidence: verified]`
- **`repeater` requires `repeats`; `condition`/`stopif` require `iff`.** Each errors (via `require_iff` or a direct check) if the mandatory arg is missing or names a non-function. `[evidence: verified]`
- **`cond_lua`'s `cond_code` is not `%`/`#`\`-dereferenced** — same rule as `luaexec`'s `code`: the C dereferencer is bypassed so the Lua can reference blobs created by earlier conditionally-run instances. Read arg values via `desync.arg.<name>`. `[evidence: verified]`
- `cond_tcp_has_ts` is the real function name in code; the manual's `cond_tcp_ts` is a documentation spelling — use `cond_tcp_has_ts` in `iff=`/`cond=`. `[evidence: verified]`

## nfqws1 → nfqws2 migration

**N/A — new in nfqws2, no nfqws1 analog.** All four orchestrators and the iff functions are nfqws2-only `[evidence: verified]`.

## Router config formatting

Orchestrators stack in a profile like any `--lua-desync` line; subordinate instances follow them in order `[evidence: verified]`.

```
--lua-desync=repeater:repeats=2:instances=2
  --lua-desync=fake:blob=tls_default:strategy=1
  --lua-desync=multisplit:pos=2,midsld:strategy=1
  --lua-desync=multidisorder:pos=host:strategy=2
```

Here the two `strategy=1` instances run twice (`1-2-1-2`) then the `strategy=2` instance runs once `[evidence: verified]` (mechanism); `[evidence: community-observed]` (composition pattern).

## Cross-references

`circular.md` (the other `zapret-auto.lua` orchestrator — bidirectional: `circular` links here for `stopif` as a nested halt), `luaexec` (same `load`+`pcall` pattern used by `cond_lua`), `detect-payload-str.md` (`cond_payload_str` is the iff counterpart of the detector), `fake`/`multisplit`/`multidisorder` (typical subordinate instances). Full migration: `../migration.md`.

## Source mapping

Upstream code: `lua/zapret-auto.lua:525-577` (`repeater`), `:451-464` (`condition`), `:469-498` (`per_instance_condition`), `:505-515` (`stopif`); iff functions `:388-393` (`cond_true`/`cond_false`), `:395-397` (`cond_random`), `:402-407` (`cond_payload_str`), `:409-411` (`cond_tcp_has_ts`), `:413-434` (`cond_lua`); `require_iff` helper `:437-444`.
