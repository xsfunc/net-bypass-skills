# out-range — packet-range filter

`--out-range` / `--in-range` restrict the subsequent `--lua-desync` functions to a **range of packets** in a connection. `--out-range` counts outgoing packets (client → server); `--in-range` counts incoming (server → client). Each scopes forward until the next `--out-range`/`--in-range` or the end of the profile (see `arg-ordering.md`). `[evidence: community-observed]` (filter model from upstream documentation).

## Format

```
--out-range=[(n|a|d|s|p|b|x)<int>](-|<)[(n|a|d|s|p|b|x)<int>]
            ───────────────────────────────────────────
                   FROM        SEPARATOR      TO
```

`[evidence: verified]` (flag syntax is code-defined; `p` prefix per `docs/manual.md` §range syntax).

### Prefixes (counting modes)

| Prefix | Counts | Evidence |
|--------|--------|----------|
| `n` | packet **n**umber — ordinal of intercepted packets in the chosen direction | verified |
| `d` | **d**ata packets — only packets carrying L7 payload (empty ACK/FIN/RST excluded) | verified |
| `s` | **s**equence — relative TCP sequence number | verified |
| `p` | tcp relative sequence **u**pper bound of the current packet (= `s` + payload size, within 2 GB) — use to bound a range by the current packet's last byte | verified |
| `b` | **b**yte count — bytes transferred | verified |
| `a` | **a**lways — from the start (no number) | verified |
| `x` | ne**x**t/never — never (no number) | verified |

### Separators

| Sep | Meaning | Evidence |
|-----|---------|----------|
| `-` | **inclusive** end position | verified |
| `<` | **exclusive** end position | verified |

All counters count **only packets that actually reached the engine** — i.e. were captured by the NFQUEUE rule (router) and not filtered out earlier. A packet that bypasses the queue does not increment `n`/`d`. `[evidence: verified]`

## Examples

```
--out-range=d1-d10      # 1st through 10th data packet, inclusive
--out-range=d1<d10      # 1st through 9th (10th excluded)
--out-range=-d10        # from start (always) through 10th data packet, inclusive
--out-range=d5-         # from 5th data packet to infinity
--out-range=d10-d10     # exactly the 10th data packet
--out-range=d10<d11     # only the 10th (11th excluded)
--out-range=s100-p2000  # from relative seq 100 through the current packet's last byte (s + payload size)
--out-range=-d10 --lua-desync=my_func   # my_func fires only on the first 10 data packets
```

`[evidence: verified]` (flag syntax, semantics).

## What is a "data packet" (`d`)?

A **data packet** carries L7 payload. Empty ACK, FIN, RST without payload **do not count** as `d`. `n` counts every intercepted packet (including empty ACK), `d` only payload-bearing ones.

```
out (client → server):
  1) SYN              → n=1, d=0
  2) ACK (empty)      → n=2, d=0     (if intercepted)
  3) ClientHello/HTTP → n=3, d=1
```

`[evidence: verified]` (counter semantics).

## `--out-range` vs `--in-range` — direction

`--out-range` counts **only outgoing** packets; `--in-range` counts **only incoming**. A common trap is to count `n` "globally across the connection" and include the SYN-ACK — but SYN-ACK is incoming and only visible to `--in-range`. `[evidence: verified]`

## Gotcha: `d` is more stable than `n` for targeting the first data packets

When you want to act on "the first N packets with data" (the usual case — ClientHello, QUIC Initial, etc.), prefer `d` over `n`. `[evidence: community-observed]`

Reason: `n` counts every intercepted packet including empty ACKs, so its value depends on **which packets the capture rule queues**. On the router, the nftables/NFQUEUE rule may not queue empty ACKs (or may queue them depending on the rule), which shifts `n` and can make `n2<n3` land on the wrong packet. `d` skips empty ACKs by definition and lands deterministically on payload-bearing packets regardless of the queue rule. `[evidence: community-observed]` (originally documented for the Windows engine where `--wf-tcp-empty=0` skips empty ACKs; the same `n`-skip risk arises on the router if the NFQUEUE rule does not queue empty ACKs — verify with your queue rule, see `zapret2-router-deploy`).

If you need to target an empty ACK explicitly, ensure the NFQUEUE rule queues it and use `n`; otherwise use `d`. `[evidence: community-observed]`

## Practical use

The typical pattern is `--out-range=-dN` — act only on the first N data packets — because DPI inspects the start of a connection and the rest is encrypted/irrelevant:

```
--filter-l7=tls --payload=tls_client_hello --out-range=-d10
--lua-desync=fake:blob=fake_default_tls:tcp_md5
--lua-desync=multisplit:pos=1,midsld
```

`[evidence: community-observed]` (composition from upstream presets); `[evidence: hypothesis]` (effectiveness — "DPI inspects only the start" is ISP-dependent; confirm with `blockcheck2`).

## Gotchas

- **Counters count only intercepted packets.** If the NFQUEUE rule does not queue a packet, it does not increment `n`/`d` — the range shifts. Verify the queue rule in `zapret2-router-deploy`. `[evidence: community-observed]`
- **`--out-range`/`--in-range` must precede `--lua-desync`.** Reversed order leaves the desync unscoped. See `arg-ordering.md`. `[evidence: verified]`
- **`d` vs `n` choice is queue-rule-dependent.** `d` is deterministic for "first data packets"; `n` is only safe when you know exactly which packets the queue rule delivers. `[evidence: community-observed]`

## Cross-references

`arg-ordering.md` (the `--out-range`-before-`--lua-desync` rule, scope reset); `payload.md` (further per-packet narrowing by payload type); `filter.md` (profile-scope filters); `zapret2-router-deploy` (NFQUEUE/nftables queue rule — determines what `n`/`d` actually count).

## Source mapping

Upstream documentation: `docs/manual.md` §range syntax (prefix modes `n/d/s/p/b/a/x`, separators, data-packet semantics, direction split); `p` = tcp relative sequence upper bound (= `s` + payload size, within 2 GB). No single code path cited — model distilled from upstream range-filter documentation; `n`-vs-`d` stability reasoning preserved from upstream guidance and re-grounded for the router (NFQUEUE queue-rule dependency).
