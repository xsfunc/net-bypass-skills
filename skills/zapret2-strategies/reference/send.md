# send — emit the current dissect with modifiers

## Lua signature

`function send(ctx, desync)` — `lua/zapret-antidpi.lua:90-109` `[evidence: verified]` CLI: `--lua-desync=send[:arg=...]`

## What it does

Sends the current dissect as a separate packet after applying fooling/ipid/ipfrag/reconstruct/rawsend modifications. It returns no verdict (`VERDICT_PASS` default) — **the original is NOT cancelled**; use a separate `drop` instance to cancel it `[evidence: verified]`. This is the "send current dissect with modifiers" primitive that, combined with `drop`, replaces nfqws1 `--dpi-desync=ipfrag2` and `--dup`/`--orig` send patterns `[evidence: community-observed]` (pattern from upstream migration examples).

## Arguments (own)

| Arg | Type | Default | Notes | Evidence |
|-----|------|---------|-------|----------|
| `direction` | `in`/`out`/`any` | `any` | Standard direction filter. | verified |
| `fooling` | fooling flags | none | Standard fooling applied to the sent copy. | verified |
| `ipid` | ip_id opts | `none` | Standard ipid; **default mode is `none`** (no IP-ID modification). | verified |
| `ipfrag` | ipfrag opts | none | Standard ipfrag — the `send:ipfrag:ipfrag_pos_*=N` form replaces nfqws1 `ipfrag2`. | verified |
| `reconstruct` | reconstruct opts | none | Standard reconstruct. | verified |
| `rawsend` | rawsend opts | none | Standard rawsend. Sub-args: `repeats`, `fwmark`, `ifout`. | verified |
| `delay` | number (ms) | none | Delay the send by N ms via a per-dissect timer. **Multiple `send` with `delay` replace the previous send** — no queue; if you need ordered delayed variants, write a custom function. | verified |

## Verdict & protocol

- Verdict: `VERDICT_PASS` (no verdict returned — original also passes) `[evidence: verified]`.
- Protocol: TCP and UDP (sends whatever the current dissect is).

## Gotchas

- **Does NOT cancel the original.** Without a following `drop` instance, both the modified copy and the original leave the wire (duplication). The canonical pattern is `send:... --lua-desync=drop`. `[evidence: verified]`
- **`delay` replaces, it does not queue.** Each delayed `send` overwrites the previous pending delayed send for the same dissect; you cannot stack several delayed variants in strict order with `send` alone. `[evidence: verified]`
- `ip_id` defaults to `none` here (contrast techniques that default `ip_id` differently) — opt in explicitly if you need IP-ID fooling on the sent copy. `[evidence: verified]`
- `apply_fooling` and `apply_ip_id` act on a `deepcopy` of the dissect, so the modifications affect only the sent copy, not the original that continues to `drop`/pass. `[evidence: verified]`

## nfqws1 → nfqws2 migration

| nfqws1 | nfqws2 |
|--------|--------|
| `--dpi-desync=ipfrag2 --dpi-desync-ipfrag-pos-udp=8` | `--lua-desync=send:ipfrag:ipfrag_pos_udp=8 --lua-desync=drop` |
| `--dpi-desync=ipfrag2 --dpi-desync-ipfrag-pos-tcp=32` | `--lua-desync=send:ipfrag:ipfrag_pos_tcp=32 --lua-desync=drop` |
| `--dup`/`--orig` send patterns | `send:... --lua-desync=drop` (explicit emit + cancel) |

nfqws1 bundled "send a modified copy and drop the original" into single flags; nfqws2 factors this into `send` (emit) + `drop` (cancel) so the two concerns compose freely `[evidence: verified]`.

## Cross-references

`drop` (the cancel half), `pktmod` (modify the original in place instead of sending a copy), `tcpseg`/`fake` (other no-verdict senders), `luaexec` (dynamic blob generation for `send`). Full fooling-flag + send-pattern migration: `../migration.md`; fooling-flag syntax: `zapret2-engine-reference`.

## Source mapping

Upstream code: `lua/zapret-antidpi.lua:90-109` (`send`, including the `send_timer_delayed` helper at `:106-109`).
