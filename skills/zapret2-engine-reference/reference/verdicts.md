# verdicts — NFQUEUE verdicts & multi-instance aggregation

Every `--lua-desync` instance returns a **verdict** telling the engine what to do with the intercepted packet. nfqws2 defines three main verdicts plus one separate bit (`VERDICT_PRESERVE_NEXT`). When several instances run on the same packet, the engine aggregates them in a fixed priority. The conceptual model (NFQUEUE architecture, why fakes are not `MODIFY`, why filtering is mandatory) lives in `zapret2-router-deploy/reference/theory.md` §3 — this card owns the **flag-level** verdict reference and the aggregation rule. `[evidence: verified]` (verdict constants and aggregation are engine-defined in `nfq2/nfqws.c`; `VERDICT_PRESERVE_NEXT` is a separate bit on the main verdict).

## The four verdicts

| Verdict | Effect | Evidence |
|---------|--------|----------|
| `VERDICT_PASS` | send the packet as-is, ignoring dissect changes (the dissect may still have been used for analysis/rawsend). | verified |
| `VERDICT_MODIFY` | reconstruct and send the **modified** dissect (bytes changed by the instance are written back). | verified |
| `VERDICT_DROP` | drop the current packet (it "disappears" — used by `fake`-style techniques that replace the original with a rawsend). | verified |
| `VERDICT_PRESERVE_NEXT` | **separate bit** OR-ed onto the main verdict, not a standalone return. Use the "next protocol" fields already present in the ipv6 header & extension headers instead of auto-generating them on reconstruct. | verified |

`[evidence: verified]` (verdict semantics are NFQUEUE-standard for `PASS`/`DROP`/`MODIFY`; `MODIFY`=reconstruct and `VERDICT_PRESERVE_NEXT` as a separate bit are engine behaviour, `nfq2/nfqws.c`).

`VERDICT_PRESERVE_NEXT` matters for IPv6 extension-header techniques (`ip6_hopbyhop`/`ip6_destopt`/`ip6_routing`/`ipfrag_next` — see `fooling.md`): without it the engine recalculates the "next protocol" chain on reconstruct, which can collapse an inserted header chain; with it the original next-protocol fields are kept.

## Aggregation across instances

When multiple Lua instances run on the same packet, the engine combines their verdicts:

- `MODIFY` overrides `PASS`.
- `DROP` overrides both `MODIFY` and `PASS`.
- `PRESERVE_NEXT` is applied if **any** instance returned it (it is a bit, not a competing value).
- No return = `VERDICT_PASS`.

```
final = PASS
if any instance returned MODIFY : final = MODIFY
if any instance returned DROP   : final = DROP
if any instance returned PRESERVE_NEXT : final |= PRESERVE_NEXT
```

`[evidence: verified]` (aggregation priority `DROP > MODIFY > PASS` with `PRESERVE_NEXT` as a separate bit is engine-defined; the 3-verdict priority is also covered in `zapret2-router-deploy/reference/theory.md` §3 "Verdict priority").

## Gotchas

- **`PRESERVE_NEXT` is a bit, not a verdict level.** Returning it does not send or drop the packet — it only requests that the next-protocol fields be preserved on reconstruct. Pair it with `MODIFY` (or let `MODIFY` come from another instance). `[evidence: verified]`
- **One `DROP` is enough to block the original.** A `fake` that sends an extra packet (rawsend) but does not `DROP` leaves the original going through (see `zapret2-strategies/reference/fake.md`). `[evidence: verified]`
- **`MODIFY` reconstructs from the dissect, not patches raw.** Bytes the instance did not touch are rebuilt from the parsed structure — do not assume a raw byte patch survives. `[evidence: verified]`

## Cross-references

`zapret2-router-deploy/reference/theory.md` §3 (conceptual verdicts model — NFQUEUE architecture, why fakes are not `MODIFY`, verdict priority); `zapret2-strategies/reference/<technique>.md` (each card names the verdict its technique returns — e.g. `fake.md`); `fooling.md` (`ipfrag_next` and `ip6_*` extension-header chaining that motivate `PRESERVE_NEXT`); `core-flags.md` (`--intercept=0` — run `--lua-init` then exit, no verdict path at all).

## Source mapping

Upstream code: `nfq2/nfqws.c` (verdict constants `VERDICT_PASS`/`VERDICT_MODIFY`/`VERDICT_DROP`/`VERDICT_PRESERVE_NEXT`, multi-instance aggregation). Upstream documentation: `docs/manual.md` §desync (verdict return values, `PRESERVE_NEXT` as a separate bit). The 3-verdict priority `DROP > MODIFY > PASS` is mirrored in `zapret2-router-deploy/reference/theory.md` §3.
