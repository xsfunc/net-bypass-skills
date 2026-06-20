# pktmod — modify the current dissect in place

## Lua signature

`function pktmod(ctx, desync)` — `lua/zapret-antidpi.lua:114-123` `[evidence: verified]` CLI: `--lua-desync=pktmod[:arg=...]`

## What it does

Applies fooling and ip_id modifications to the **current dissect in place** — no separate send, no DROP. Returns `VERDICT_MODIFY` so the engine sends the modified original `[evidence: verified]`. It is the nfqws2 replacement for nfqws1 `--orig-ttl=… --orig-mod-start=… --orig-mod-cutoff=…` style tricks: apply fooling to the original packet itself, then let a later instance cut/send `[evidence: community-observed]` (pattern from upstream migration examples). Because the modification is visible to subsequent instances in the same profile, `pktmod` is the primitive for "fool the original, then segment it".

## Arguments (own)

| Arg | Type | Default | Notes | Evidence |
|-----|------|---------|-------|----------|
| `direction` | `in`/`out`/`any` | `any` | Standard direction filter. | verified |
| `fooling` | fooling flags | none | Standard fooling applied to the live dissect (not a copy). | verified |
| `ipid` | ip_id opts | `none` | Standard ipid; default mode `none`. | verified |

**No `ipfrag`, no `rawsend`, no `reconstruct`, no `payload` filter** — `pktmod` only mutates headers/options of the current packet `[evidence: verified]`.

## Verdict & protocol

- Verdict: `VERDICT_MODIFY` — the engine sends the modified original; no separate rawsend, no DROP `[evidence: verified]`.
- Protocol: TCP and UDP (mutates whatever the current dissect is).

## Gotchas

- **Modifies the live dissect, not a copy.** `apply_fooling(desync)` (no `dis` argument) acts on `desync.dis` directly, so every subsequent instance in the profile sees the modified packet. This is the point — and the hazard: fooling that breaks the original (e.g. `badsum`, `tcp_ack=-66000`) will break later segmentation too. `[evidence: verified]`
- Use **safe fooling** (`tcp_ts_up`, `ip_id`, IPv6 extension headers) when a later instance will cut/send the modified packet; destructive fooling makes the server drop the real data. `[evidence: community-observed]`
- Pair with a later sender/cutter (`multisplit`, `send`, `tcpseg`) for the nfqws1 `--orig-*` flow: `pktmod` applies the original-side fooling, the next instance segments and sends. `[evidence: community-observed]`

## nfqws1 → nfqws2 migration

| nfqws1 | nfqws2 |
|--------|--------|
| `--orig-ttl=…` / `--orig-mod-start=…` / `--orig-mod-cutoff=…` | `--lua-desync=pktmod:ip_ttl=…` (apply to original) followed by a cutter/sender instance |

nfqws1 applied original-side mods through dedicated `--orig-*` flags on the same desync action; nfqws2 makes "modify the original" an explicit instance (`pktmod`) that composes with any later instance `[evidence: verified]` (`pktmod` returns `VERDICT_MODIFY` without sending; `[evidence: community-observed]` for the migration mapping).

## Cross-references

`send` (emit a modified *copy* instead of mutating the original), `drop`, `multisplit`/`tcpseg` (cutters that follow `pktmod`), `luaexec`. Full fooling-flag migration: `../migration.md`; fooling-flag syntax: `zapret2-engine-reference`.

## Source mapping

Upstream code: `lua/zapret-antidpi.lua:114-123` (`pktmod`).
