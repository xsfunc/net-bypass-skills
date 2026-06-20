# drop — cancel the current packet

## Lua signature

`function drop(ctx, desync)` — `lua/zapret-antidpi.lua:79-85` `[evidence: verified]` CLI: `--lua-desync=drop[:arg=...]`

## What it does

Returns `VERDICT_DROP` for the current packet when the direction/payload filter matches, cancelling it so the engine does not also send the original. It is the canonical pairing for any no-verdict sender (`send`, `tcpseg`, `fake`, `luaexec`-driven sends) that should *replace* the original rather than duplicate it `[evidence: verified]`. The `send:ipfrag:... --lua-desync=drop` pattern is the nfqws2 replacement for nfqws1 `--dpi-desync=ipfrag2` `[evidence: community-observed]` (pattern from upstream migration examples).

## Arguments (own)

| Arg | Type | Default | Notes | Evidence |
|-----|------|---------|-------|----------|
| `direction` | `in`/`out`/`any` | `any` | Standard direction filter. | verified |
| `payload` | payload filter | `all` | Standard payload filter; `all` drops regardless of payload type. | verified |

No fooling, no send, no ipfrag — `drop` only returns the verdict `[evidence: verified]`.

## Verdict & protocol

- Verdict: `VERDICT_DROP` `[evidence: verified]`.
- Protocol: TCP and UDP (filter-gated; not SYN-bound).

## Gotchas

- `drop` does **not** send anything — pair it with a sender (`send`/`tcpseg`/`fake`) that emits the replacement, then `drop` cancels the original. Used alone it just black-holes the packet. `[evidence: verified]`
- Default `payload=all` drops every matching packet in the direction; to match only a known-type payload (e.g. a `tcpseg` segment sent on `known`) use `--lua-desync=drop:payload=known`. `[evidence: verified]`
- `direction_cutoff_opposite` runs first, so an opposite-direction packet triggers instance cutoff on this side — `drop` then only fires on the configured direction. `[evidence: verified]`

## nfqws1 → nfqws2 migration

| nfqws1 | nfqws2 |
|--------|--------|
| `--dpi-desync=ipfrag2 --dpi-desync-ipfrag-pos-udp=8` | `--lua-desync=send:ipfrag:ipfrag_pos_udp=8 --lua-desync=drop` |
| `--dpi-desync=ipfrag2 --dpi-desync-ipfrag-pos-tcp=32` | `--lua-desync=send:ipfrag:ipfrag_pos_tcp=32 --lua-desync=drop` |

nfqws1 `ipfrag2` sent a fragmented fake *and* dropped the original in one flag; nfqws2 splits this into `send` (emit the fragment) + `drop` (cancel the original) `[evidence: verified]` (split into two instances; `[evidence: community-observed]` for the migration pattern).

## Cross-references

`send` (the emitter half of the send+drop pattern), `tcpseg` (no-verdict sender that needs `drop` to replace the original), `fake` (no-verdict; pair with `drop` to replace), `luaexec`. Full fooling-flag + send-pattern migration: `../migration.md`.

## Source mapping

Upstream code: `lua/zapret-antidpi.lua:79-85` (`drop`).
